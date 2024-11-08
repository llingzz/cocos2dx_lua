// assistserver.cpp : 此文件包含 "main" 函数。程序执行将在此处开始并结束。
//

#include <iostream>
#include "pb/pb_common.pb.h"

#include <cstdlib>
#include <iostream>
#include <memory>
#include <utility>
#include <queue>
#include <asio.hpp>

using asio::ip::tcp;

class server;
class session : public std::enable_shared_from_this<session>
{
public:
    session(std::shared_ptr<asio::ip::tcp::socket> socket, asio::io_service::strand strand, LONG token, std::function<void(LONG)> cbRemove, std::function<void(LONG,int,const std::string&)> cbHandleData) :
        socket_(socket),
        strand_(strand),
        tokenid(token),
        m_cbRemove(cbRemove), m_cbHandleData(cbHandleData),
        ready(false), inGame(false)
    {
        memset(data_, 0, sizeof(data_));
    }

    void start() {
        pb_common::data_user_info user;
        user.set_userid(tokenid);
        send(pb_common::protocol_code::protocol_user_info, user.SerializeAsString());
        do_read();
    }

    void close() {
        asio::error_code ignored_ec;
        (*socket_).shutdown(asio::ip::tcp::socket::shutdown_both, ignored_ec);
        (*socket_).close();
        if (m_cbRemove) {
            m_cbRemove(tokenid);
        }
    }

    void send(int protocol, const std::string& data) {
        pb_common::data_head pb_head;
        pb_head.set_protocol_code(protocol);
        pb_head.set_data_len(data.size());
        pb_head.set_data_str(data);
        unsigned int size = pb_head.ByteSizeLong();
        write(std::string((char*)&size, sizeof(size)) + pb_head.SerializeAsString());
    }

    void hander_data(const std::string& data) {
        pb_common::data_head head;
        auto ret = head.ParseFromString(data);
        if (!ret) { return; }
        int idx = data.size() - head.data_len();
        std::string real_data = data.substr(idx, data.size() - 1);
        if (m_cbHandleData) {
            m_cbHandleData(tokenid,head.protocol_code(), real_data);
        }
    }

    void do_read() {
        auto self(shared_from_this());
        asio::async_read(*socket_, asio::buffer(data_, head),
            asio::bind_executor(strand_,
                [this, self](asio::error_code ec, std::size_t length)
                {
                    if (!ec) {
                        auto len = *((unsigned int*)(data_));
                        memset(data_, 0, sizeof(data_));
                        asio::async_read(*socket_, asio::buffer(data_, len),
                            asio::bind_executor(strand_,
                                [this, self](asio::error_code ec, std::size_t length)
                                {
                                    if (!ec) {
                                        strand_.post(std::bind(&session::hander_data, this, std::string(data_)));
                                        memset(data_, 0, sizeof(data_));
                                        do_read();
                                    }
                                    else {
                                        close();
                                    }
                                }
                            )
                        );
                    }
                    else {
                        close();
                    }
                }
            )
        );
    }

    void write(const std::string& msg) {
        std::lock_guard<std::mutex> lk(lock);
        bool write_in_progress = !write_msgs_.empty();
        write_msgs_.push_back(msg);
        if (!write_in_progress) {
            do_write();
        }
    }

    void do_write() {
        asio::async_write((*socket_), asio::buffer(write_msgs_.front().data(), write_msgs_.front().length()),
            asio::bind_executor(strand_,
                [this](std::error_code ec, std::size_t length)
                {
                    std::lock_guard<std::mutex> lk(lock);
                    if (!ec) {
                        write_msgs_.pop_front();
                        if (!write_msgs_.empty()) {
                            do_write();
                        }
                    }
                    else {
                        close();
                    }
                }
            )
        );
    }

    bool ready;
    bool inGame;
    LONG tokenid;
    std::shared_ptr<asio::ip::tcp::socket> socket_;
    asio::io_service::strand strand_;
    enum { max_length = 1024, head = 4 };
    char data_[max_length];
    std::mutex lock;
    std::deque<std::string> write_msgs_;
    std::function<void(LONG)> m_cbRemove;
    std::function<void(LONG,int,const std::string&)> m_cbHandleData;
};

/*协议格式：数据长度(4字节)|数据*/
class server
{
public:
    server(std::string strIp, int port)
    {
        m_lTokenId = 1;
        m_pContext = std::make_unique<asio::io_service>();

        auto size = std::thread::hardware_concurrency();
        for (size_t i = 0; i < size; ++i) {
            m_pStrands.emplace_back(std::make_unique<asio::io_service::strand>(*m_pContext));
        }
        m_pThread = std::make_unique<std::thread>(
            [=]() {
                std::vector<std::thread> threads;
                for (size_t i = 0; i < size; ++i) {
                    threads.emplace_back([&]() {
                            asio::io_service::work work(*m_pContext);
                            m_pContext->run();
                        }
                    );
                }
                for (size_t i = 0; i < threads.size(); ++i) {
                    threads[i].join();
                }
            }
        );

        m_pAcceptor = std::make_unique<tcp::acceptor>(*m_pContext);
        asio::ip::tcp::resolver resolver(*m_pContext);
        auto query = asio::ip::tcp::resolver::query(strIp, std::to_string(port));
        asio::ip::tcp::endpoint endpoint(*resolver.resolve(query));
        m_pAcceptor->open(endpoint.protocol());
        m_pAcceptor->set_option(asio::ip::tcp::acceptor::reuse_address(TRUE));
        m_pAcceptor->bind(endpoint);
        m_pAcceptor->listen();
        for (auto i = 0; i < 10; ++i) {
            do_accept();
        }
    }

    void do_accept()
    {
        auto socket_ = std::make_shared<asio::ip::tcp::socket>(*m_pContext);
        m_pAcceptor->async_accept(*socket_,
            [this,socket_](asio::error_code ec)
            {
                if (!ec) {
                    auto token = m_lTokenId++;
                    const auto& strand = m_pStrands[token % m_pStrands.size()];
                    std::lock_guard<std::mutex> lk(lock);
                    m_mapSessions[token] = std::make_shared<session>(socket_, *strand, token,
                        [this](LONG token) {
                            if (m_mapSessions.find(token) != m_mapSessions.end()) {
                                m_mapSessions.erase(token);
                            }
                        },
                        [this](LONG token, int protocol , const std::string& real_data) {
                            auto ret = true;
                            switch (protocol) {
                                case pb_common::protocol_code::protocol_ready:
                                {
                                    pb_common::data_ready _ready;
                                    ret = _ready.ParseFromString(real_data);
                                    if (!ret) { break; }
                                    {
                                        std::lock_guard<std::mutex> lk(lock);
                                        if (m_mapSessions[token].get()) {
                                            m_mapSessions[token]->ready = true;
                                        }
                                    }
                                    printf("token %d set ready\n", _ready.userid());
                                    break;
                                }
                                case pb_common::protocol_code::protocol_repair_frame:
                                {
                                    pb_common::data_repair_frame repair;
                                    ret = repair.ParseFromString(real_data);
                                    if (!ret) { break; }
                                    {
                                        std::lock_guard<std::mutex> lk(lock_repair);
                                        if (m_mapRepair.find(token) != m_mapRepair.end()) {
                                            if (repair.frameid() < m_mapRepair[token]) {
                                                m_mapRepair[token] = repair.frameid();
                                            }
                                        }
                                        else {
                                            m_mapRepair[token] = repair.frameid();
                                        }
                                    }
                                    printf("token %d repair frameid begin %d\n", repair.userid(), repair.frameid());
                                    break;
                                }
                                default:
                                {
                                    break;
                                }
                            }
                        }
                    );
                    m_mapSessions[token]->start();
                }
                do_accept();
            }
        );
    }

    void notify_all(int protocol, const std::string& msg)
    {
        for (auto& iter : m_mapSessions) {
            if (iter.second.get() && iter.second.get()->inGame) {
                iter.second.get()->send(protocol, msg);
            }
        }
    }

    LONG m_lTokenId;
    std::unique_ptr<tcp::acceptor> m_pAcceptor;
    std::vector<std::unique_ptr<asio::io_service::strand>> m_pStrands;
    std::unique_ptr<asio::io_service> m_pContext;
    std::unique_ptr<std::thread> m_pThread;
    std::mutex lock;
    std::map<LONG, std::shared_ptr<session>> m_mapSessions;
    std::mutex lock_repair;
    std::map<LONG, int> m_mapRepair;
};

using asio::ip::udp;
class udp_server {
public:
    udp_server(asio::io_context& io_context, short port)
        : socket_(io_context, udp::endpoint(udp::v4(), port)), currentFrame(0)
    {
        memset(data_, 0, max_length);
        do_receive();
    }

    void do_receive()
    {
        socket_.async_receive_from(asio::buffer(data_, max_length), sender_endpoint_,
            [this](asio::error_code ec, std::size_t bytes_recvd) {
                if (!ec && bytes_recvd > 0) {
                    pb_common::data_ope frame;
                    if (frame.ParseFromString(std::string(data_, bytes_recvd))) {
                        std::lock_guard<std::mutex> lk(lock);
                        auto userid = frame.userid();
                        udp_sessions[userid] = sender_endpoint_;
                        printf_s("recv userid %d frameid %d opecode %d\n", userid, currentFrame, frame.opecode());
                        frames_[currentFrame][userid].insert(std::make_pair(frame.frameid(), std::move(frame)));
                    }
                }
                do_receive();
            }
        );
    }

    void update(bool bStart, std::map<LONG,int>& mapRepair)
    {
        if (!bStart) { return; }
        std::lock_guard<std::mutex> lk(lock);
        int frameid = currentFrame++;
        pb_common::data_ope_frames frames;
        frames.set_frameid(frameid);
        if (frames_.find(frameid) != frames_.end()) {
            for (auto& iter : frames_[frameid]) {
                auto user_frame = frames.add_frames();
                if (user_frame) {
                    user_frame->set_userid(iter.first);
                    if (mapRepair.find(iter.first) != mapRepair.end()) {
                        for (auto i = mapRepair[iter.first]; i < frameid; ++i) {
                            if (frames_.find(i) != frames_.end() && frames_[i].find(iter.first) != frames_[i].end()) {
                                for (auto& itIn : frames_[i][iter.first]) {
                                    user_frame->add_opecode(itIn.second.opecode());
                                }
                            }
                            printf_s("userid %d repair frame %d\n", iter.first, i);
                        }
                    }
                    for (auto& it : iter.second) {
                        user_frame->add_opecode(it.second.opecode());
                    }
                }
            }
        }
        auto data = frames.SerializeAsString();
        for (auto& iter : udp_sessions) {
            //socket_.send_to(asio::buffer(data.c_str(), data.size()), iter.second);
            socket_.async_send_to(asio::buffer(data.c_str(), data.size()), iter.second,
                [this](asio::error_code /*ec*/, std::size_t /*bytes_sent*/) {
                    // do nothing
                }
            );
        }
        //printf_s("send frameid %d opecount %d\n", frameid, frames.mutable_frames()->size());
    }

public:
    udp::socket socket_;
    udp::endpoint sender_endpoint_;
    enum { max_length = 1024 };
    char data_[max_length];
    std::mutex lock;
    int currentFrame;
    std::map<int, std::map<int, std::map<int, pb_common::data_ope>>> frames_;
    std::map<int, udp::endpoint> udp_sessions;
};

class gameserver : public server {
public:
    gameserver(std::string strIp, int tcp_port, int udp_port) :
        server(strIp, tcp_port), game_start(false) {
        m_udpServer = std::make_unique<udp_server>(*m_pContext, udp_port);
        auto fps = 1000 / 15;
        m_pThread = std::make_unique<std::thread>(
            [=]() {
                while (true) {
                    std::this_thread::sleep_for(std::chrono::milliseconds(fps));
                    if (!game_start) {
                        std::lock_guard<std::mutex> lk(lock);
                        if (m_mapSessions.size() <= 0) { continue; }
                        bool allReady = true;
                        std::vector<int> userids;
                        for (auto& iter : m_mapSessions) {
                            if (!iter.second.get() || !iter.second.get()->ready) {
                                allReady = false;
                                break;
                            }
                            userids.push_back(iter.first);
                        }
                        if (allReady) {
                            game_start = true;
                            pb_common::data_begin begin;
                            begin.set_rand_seed(time(nullptr));
                            begin.mutable_userids()->CopyFrom({ userids.begin(), userids.end() });
                            for (auto& iter : m_mapSessions) {
                                if (iter.second.get()) {
                                    iter.second.get()->inGame = true;
                                    iter.second.get()->send(pb_common::protocol_code::protocol_begin, begin.SerializeAsString());
                                }
                            }
                        }
                    }
                    std::map<LONG, int> mapRepair;
                    {
                        std::lock_guard<std::mutex> lk(lock_repair);
                        std::swap(mapRepair, m_mapRepair);
                    }
                    if (m_udpServer) { m_udpServer->update(game_start, mapRepair); }
                }
            }
        );
    }

    bool game_start;
    std::unique_ptr<std::thread> m_pThread;
    std::unique_ptr<udp_server> m_udpServer;
};

int main()
{
    GOOGLE_PROTOBUF_VERIFY_VERSION;

    try {
        gameserver s("127.0.0.1", 8888, 8889);
        auto ch = getchar();
    }
    catch (std::exception& e) {
        std::cerr << "Exception: " << e.what() << "\n";
    }

    google::protobuf::ShutdownProtobufLibrary();
    return 0;
}
