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
    session(std::shared_ptr<tcp::socket> socket, asio::io_service::strand strand, LONG token, std::function<void(LONG)> cbRemove, std::function<void(LONG,int,const std::string&)> cbHandleData) :
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
        (*socket_).shutdown(tcp::socket::shutdown_both, ignored_ec);
        (*socket_).close();
        if (m_cbRemove) {
            m_cbRemove(tokenid);
        }
    }

    /*协议格式：数据长度(4字节)|数据*/
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
    std::shared_ptr<tcp::socket> socket_;
    asio::io_service::strand strand_;
    enum { max_length = 1024, head = 4 };
    char data_[max_length];
    std::mutex lock;
    std::deque<std::string> write_msgs_;
    std::function<void(LONG)> m_cbRemove;
    std::function<void(LONG,int,const std::string&)> m_cbHandleData;
};

class server
{
public:
    server(std::string strIp, int port, std::function<void(LONG,int,const std::string&)> cb)
    {
        m_callback = cb;
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
        tcp::resolver resolver(*m_pContext);
        auto query = tcp::resolver::query(strIp, std::to_string(port));
        tcp::endpoint endpoint(*resolver.resolve(query));
        m_pAcceptor->open(endpoint.protocol());
        m_pAcceptor->set_option(tcp::acceptor::reuse_address(TRUE));
        m_pAcceptor->bind(endpoint);
        m_pAcceptor->listen();
        for (auto i = 0; i < 10; ++i) {
            do_accept();
        }
    }

    void do_accept()
    {
        auto socket_ = std::make_shared<tcp::socket>(*m_pContext);
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
                        m_callback
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
    std::function<void(LONG, int, const std::string&)> m_callback;
    std::mutex lock;
    std::map<LONG, std::shared_ptr<session>> m_mapSessions;
};

using asio::ip::udp;
class udp_server {
public:
    udp_server(asio::io_context& io_context, short port, std::function<void(const std::string&,const udp::endpoint&)> cb)
        : socket_(io_context, udp::endpoint(udp::v4(), port)), m_callback(cb)
    {
        memset(data_, 0, max_length);
        do_receive();
    }

    void do_receive()
    {
        socket_.async_receive_from(asio::buffer(data_, max_length), sender_endpoint_,
            [this](asio::error_code ec, std::size_t bytes_recvd) {
                if (!ec && bytes_recvd > 0) {
                    if (m_callback) {
                        m_callback(std::string(data_, bytes_recvd), sender_endpoint_);
                    }
                }
                do_receive();
            }
        );
    }

    void send_data(const std::string& data, const udp::endpoint& ed)
    {
        //socket_.send_to(asio::buffer(data.c_str(), data.size()), ed);
        socket_.async_send_to(asio::buffer(data.c_str(), data.size()), ed,
            [this](asio::error_code /*ec*/, std::size_t /*bytes_sent*/) {
                // do nothing
            }
        );
    }

public:
    udp::socket socket_;
    udp::endpoint sender_endpoint_;
    enum { max_length = 1024 };
    char data_[max_length];
    std::function<void(const std::string&,const udp::endpoint&)> m_callback;
};

class gameserver : public server {
public:
    gameserver(std::string strIp, int tcp_port, int udp_port) :
        server(strIp, tcp_port, std::bind(&gameserver::handle_tcp_data, this, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3)), game_start(false), currentFrame(0)
    {
        m_udpServer = std::make_unique<udp_server>(*m_pContext, udp_port, std::bind(&gameserver::handle_udp_data, this, std::placeholders::_1, std::placeholders::_2));
        m_pThread = std::make_unique<std::thread>(
            [=]() {
                auto fps = 1000 / 15;
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
                            begin.set_rand_seed((uint32_t)time(nullptr));
                            begin.mutable_userids()->CopyFrom({ userids.begin(), userids.end() });
                            for (auto& iter : m_mapSessions) {
                                if (iter.second.get()) {
                                    iter.second.get()->inGame = true;
                                    iter.second.get()->send(pb_common::protocol_code::protocol_begin, begin.SerializeAsString());
                                }
                            }
                        }
                    }
                    if (game_start) {
                        std::lock_guard<std::mutex> lk(lock_frames);
                        int frameid = currentFrame++;
                        for (auto& iter : udp_sessions) {
                            pb_common::data_frames frames;
                            auto begin_frame = frame_sync[iter.first] < 0 ? 0 : frame_sync[iter.first];
                            for (auto i = begin_frame; i <= frameid; ++i) {
                                auto frame = frames.add_frames();
                                frame->set_frameid(i);
                                if (frames_.find(frameid) != frames_.end()) {
                                    for (auto& iter : frames_[frameid]) {
                                        auto user_frame = frame->add_frames();
                                        if (user_frame) {
                                            user_frame->set_userid(iter.first);
                                            for (auto& it : iter.second) {
                                                user_frame->add_opecode(it.second.opecode());
                                            }
                                        }
                                    }
                                }
                            }
                            pb_common::data_head pb_head;
                            pb_head.set_protocol_code(pb_common::protocol_code::protocol_frame);
                            pb_head.set_data_len(frames.ByteSizeLong());
                            pb_head.set_data_str(frames.SerializeAsString());
                            if (m_udpServer) {
                                m_udpServer->send_data(pb_head.SerializeAsString(), iter.second);
                            }
                        }
                    }
                }
            }
        );
    }

    void handle_tcp_data(LONG token, int protocol, const std::string& real_data)
    {
        switch (protocol) {
            case pb_common::protocol_code::protocol_ready:
            {
                pb_common::data_ready _ready;
                if (!_ready.ParseFromString(real_data)) { break; }
                {
                    std::lock_guard<std::mutex> lk(lock);
                    if (m_mapSessions[token].get()) {
                        m_mapSessions[token]->ready = true;
                    }
                }
                printf("token %d set ready\n", _ready.userid());
                break;
            }
            default:
            {
                break;
            }
        }
    }

    void handle_udp_data(const std::string& data, const udp::endpoint& ed)
    {
        pb_common::data_head head;
        if (!head.ParsePartialFromString(data)) { return; }
        switch (head.protocol_code()) {
        case pb_common::protocol_code::protocol_frame:
        {
            pb_common::data_ope frame;
            if (!frame.ParseFromString(head.data_str())) { return; }
            auto userid = frame.userid();
            auto frameid = frame.frameid();
            auto opecode = frame.opecode();
            std::lock_guard<std::mutex> lk(lock_frames);
            udp_sessions[userid] = ed;
            if (frame_sync.find(userid) == frame_sync.end()) {
                frame_sync.insert(std::make_pair(userid, frameid));
            }
            if (frame_sync[userid] <= frameid) {
                frame_sync[userid] = frameid;
            }
            frames_[currentFrame][userid].insert(std::make_pair(frameid, std::move(frame)));
            printf_s("recv userid %d frameid %d frameid_svr %d opecode %d\n", userid, frameid, currentFrame, opecode);
            break;
        }
        default:
            break;
        }
    }

public:
    bool game_start;
    std::unique_ptr<std::thread> m_pThread;
    std::unique_ptr<udp_server> m_udpServer;
    std::mutex lock_frames;
    int currentFrame;
    std::map<int, std::map<int, std::map<int, pb_common::data_ope>>> frames_;
    std::map<int, udp::endpoint> udp_sessions;
    std::map<int, int> frame_sync;
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
