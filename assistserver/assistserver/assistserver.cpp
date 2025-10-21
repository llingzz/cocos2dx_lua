// assistserver.cpp : 此文件包含 "main" 函数。程序执行将在此处开始并结束。
//

#include <iostream>
#include "redispool/redispool.h"
#include "pb/pb_common.pb.h"

#include <cstdlib>
#include <iostream>
#include <memory>
#include <utility>
#include <queue>
#include <asio.hpp>

static
time_t getMs() {
    std::chrono::time_point<std::chrono::system_clock, std::chrono::milliseconds> tp = std::chrono::time_point_cast<std::chrono::milliseconds>(std::chrono::system_clock::now());
    auto tmp = std::chrono::duration_cast<std::chrono::milliseconds>(tp.time_since_epoch());
    return tmp.count();
}

using asio::ip::tcp;
class session : public std::enable_shared_from_this<session> {
public:
    session(std::shared_ptr<tcp::socket> socket, asio::io_service::strand strand, LONG token, std::function<void(LONG)> cbRemove, std::function<void(LONG,int,const std::string&)> cbHandleData) :
        socket_(socket), strand_(strand), tokenid(token), m_cbRemove(cbRemove), m_cbHandleData(cbHandleData), bSending(false)
    {
        memset(data_, 0, sizeof(data_));
    }

    void start() {
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
        std::lock_guard<std::mutex> lk(lock_msg);
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
                    std::lock_guard<std::mutex> lk(lock_msg);
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

    LONG tokenid;
    std::shared_ptr<tcp::socket> socket_;
    asio::io_service::strand strand_;
    enum { max_length = 1024, head = 4 };
    char data_[max_length];
    std::mutex lock_msg;
    bool bSending;
    std::deque<std::string> write_msgs_;
    std::function<void(LONG)> m_cbRemove;
    std::function<void(LONG,int,const std::string&)> m_cbHandleData;
};
class tcp_server {
public:
    tcp_server(std::shared_ptr<asio::io_service> io, std::string strIp, int port, std::function<void(LONG,int,const std::string&)> cb, std::function<void(LONG)> rm_session_cb) :
        m_pContext(io), m_callback(cb), m_lTokenId(1), m_tcpSessionRemoveCb(rm_session_cb)
    {
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
    ~tcp_server() {

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
                    std::lock_guard<std::mutex> lk(lock_session);
                    m_mapSessions[token] = std::make_shared<session>(socket_, *strand, token,
                        [this](LONG token) {
                            if (m_mapSessions.find(token) != m_mapSessions.end()) {
                                m_mapSessions.erase(token);
                            }
                            if (m_tcpSessionRemoveCb) {
                                m_tcpSessionRemoveCb(token);
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

    void tcp_send(LONG token, int protocal, const std::string& data)
    {
        std::lock_guard<std::mutex> lk(lock_session);
        if (m_mapSessions.find(token) == m_mapSessions.end()) { return; }
        if (!m_mapSessions[token].get()) {
            return;
        }
        m_mapSessions[token].get()->send(protocal, data);
    }

    LONG m_lTokenId;
    std::unique_ptr<std::thread> m_pThread;
    std::unique_ptr<tcp::acceptor> m_pAcceptor;
    std::shared_ptr<asio::io_service> m_pContext;
    std::vector<std::unique_ptr<asio::io_service::strand>> m_pStrands;
    std::function<void(LONG, int, const std::string&)> m_callback;
    std::function<void(LONG)> m_tcpSessionRemoveCb;
    std::mutex lock_session;
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
    ~udp_server() {

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

    void update_udp_session(int token, const udp::endpoint& ed)
    {
        std::lock_guard<std::mutex> lk(lock_udp);
        udp_sessions[token] = ed;
    }

    void send_data(int token, const std::string& data)
    {
        udp::endpoint ed;
        {
            std::lock_guard<std::mutex> lk(lock_udp);
            if (udp_sessions.find(token) == udp_sessions.end()) { return; }
            ed = udp_sessions[token];
        }
        //socket_.send_to(asio::buffer(data.c_str(), data.size()), ed);
        socket_.async_send_to(asio::buffer(data.c_str(), data.size()), ed,
            [this](asio::error_code /*ec*/, std::size_t /*bytes_sent*/) {
                // do nothing
            }
        );
    }

    void udp_send(LONG token, int protocal, int len, const std::string& data)
    {
        pb_common::data_head pb_head;
        pb_head.set_protocol_code(protocal);
        pb_head.set_data_len(len);
        pb_head.set_data_str(data);
        send_data(token, pb_head.SerializeAsString());
    }

public:
    udp::socket socket_;
    udp::endpoint sender_endpoint_;
    enum { max_length = 10240 };
    char data_[max_length];
    std::function<void(const std::string&,const udp::endpoint&)> m_callback;
    std::mutex lock_udp;
    std::map<int, udp::endpoint> udp_sessions;
};

class gameserver;
class gameplayer {
public:
    gameplayer(int userid, LONG token, int state) :
        m_userid(userid), m_token(token), m_state(state) {

    }
    ~gameplayer() {

    }
    int m_userid;
    int m_token;
    int m_state;
};
class gameroom {
public:
    gameroom() :
        game_start(false), all_ready(false), currentFrame(0) {

    }
    ~gameroom() {

    }
    void start_game(gameserver* pServer, int playercount);
    void input_frame(int userid, int frameid, const pb_common::data_ope& frame) {
        std::lock_guard<std::mutex> lk(lock_frames);
        if (frame_sync.find(userid) == frame_sync.end()) {
            frame_sync.insert(std::make_pair(userid, frame.ackframeid()));
        }
        if (frame_sync[userid] < frame.ackframeid()) {
            frame_sync[userid] = frame.ackframeid();
        }
        std::string strLog = "";
        for (const auto& iter : frame.opecode()) {
            if (1 == iter.opetype()) {
				pb_common::ope_move move;
				move.ParseFromString(iter.opestring());
                char szLog[1024] = { 0 };
				sprintf_s(szLog, sizeof(szLog), "%d:%d&%d|", iter.opetype(), move.movex(), move.movey());
                strLog += std::string(szLog);
			}
			else if (2 == iter.opetype()) {
                pb_common::ope_fire_bullet fire;
                fire.ParseFromString(iter.opestring());
                char szLog[1024] = { 0 };
				sprintf_s(szLog, sizeof(szLog), "%d:%d&%d&%d&%d|", iter.opetype(), fire.startposx(), fire.startposy(), fire.directionx(), fire.directiony());
                strLog += std::string(szLog);
            }
        }
        printf_s("[recv] userid %d frameid %d acked_frameid %d frameid_svr %d opecode %s\n", userid, frameid, frame.ackframeid(), currentFrame, strLog.c_str());
        frames_[currentFrame][userid].insert(std::make_pair(frameid, frame));
    }

    bool all_ready;
    bool game_start;
    std::map<int, std::shared_ptr<gameplayer>> m_mapPlayer;
    std::mutex lock_frames;
    int currentFrame;
    std::map<int, std::map<int, std::map<int, pb_common::data_ope>>> frames_;
    std::map<int, int> frame_sync;
};
class gameserver : public tcp_server, public udp_server {
public:
    gameserver(std::string strIp, int tcp_port, short udp_port, std::shared_ptr<asio::io_service> io) : m_nIncrRoomId(1),
        tcp_server(io, strIp, tcp_port, std::bind(&gameserver::handle_tcp_data, this, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3), std::bind(&gameserver::tcp_session_close, this, std::placeholders::_1)),
        udp_server(*io, udp_port, std::bind(&gameserver::handle_udp_data, this, std::placeholders::_1, std::placeholders::_2))
    {
        m_pRedisPool = RedisPool::create("127.0.0.1", 6379, "");
        m_pRedisPool->initConnection(3);
        m_pLogicThread = std::make_unique<std::thread>([=]() {
            auto playercount = 2;
            auto delta = 0;
            auto tick = getMs();
            auto fps = 1000 / 15;
            while (true) {
                auto now = getMs();
                delta += (now - tick);
                tick = now;
                while(delta >= fps)
                {
                    delta -= fps;
                    std::lock_guard<std::mutex> lk(lock_room);
                    for (auto& iter : m_mapRoom) {
                        if (iter.second->all_ready || iter.second->m_mapPlayer.size() < playercount) {
                            continue;
                        }
                        iter.second->all_ready = true;
                        for (auto& it : iter.second->m_mapPlayer) {
                            if (it.second->m_state != 1) {
                                iter.second->all_ready = false;
                                break;
                            }
                        }
                    }
                    for (auto& iter : m_mapRoom) {
                        if (iter.second->all_ready) {
                            iter.second->start_game(this, playercount);
                        }
                    }
                }
                std::this_thread::sleep_for(std::chrono::microseconds(1));
            }
        });
        register_tcp_callback(pb_common::protocol_code::protocol_register, [&](LONG token, int protocol, const std::string& real_data) {
            pb_common::data_user_register _register;
            if (!_register.ParseFromString(real_data)) { return; }
            pb_common::data_user_register_response rsp;
            rsp.set_return_code(0);
            std::string ani;
            do {
                auto res = m_pRedisPool->get(0)->RedisCommand(ani, "INCRBY user_id_generator 1");
                rsp.set_return_code(1);
                rsp.set_userid(atoi(ani.c_str()));
                {
                    std::lock_guard<std::mutex> lklk(lock_token);
                    m_mapTokenUserId[token] = rsp.userid();
                }
            } while (0);
            tcp_send(token, pb_common::protocol_code::protocol_register_response, rsp.SerializeAsString());
        });
        register_tcp_callback(pb_common::protocol_code::protocol_join_room, [&](LONG token, int protocol, const std::string& real_data) {
            pb_common::data_user_join_room _room;
            if (!_room.ParseFromString(real_data)) { return; }
            pb_common::data_user_join_room_response rsp;
            rsp.set_userid(_room.userid());
            {
                std::lock_guard<std::mutex> lk(lock_room);
                for (auto& iter : m_mapRoom) {
                    if (iter.second->game_start) { continue; }
                    rsp.set_roomid(iter.first);
                    break;
                }
                if (rsp.roomid() <= 0) {
                    rsp.set_roomid(m_nIncrRoomId++);
                    m_mapRoom.insert(std::make_pair(rsp.roomid(), std::make_shared<gameroom>()));
                }
                auto player = std::make_shared<gameplayer>(_room.userid(), token, 0);
                m_mapRoom[rsp.roomid()]->m_mapPlayer.insert(std::make_pair(_room.userid(), player));
            }
            tcp_send(token, pb_common::protocol_code::protocol_join_room_response, rsp.SerializeAsString());
        });
        register_tcp_callback(pb_common::protocol_code::protocol_ready, [&](LONG token, int protocol, const std::string& real_data) {
            pb_common::data_ready _ready;
            if (!_ready.ParseFromString(real_data)) { return; }
            pb_common::data_ready_response rsp;
            rsp.set_userid(_ready.userid());
            rsp.set_roomid(_ready.roomid());
            rsp.set_return_code(0);
            do {
                std::lock_guard<std::mutex> lk(lock_room);
                if (m_mapRoom.find(_ready.roomid()) == m_mapRoom.end()) { break; }
                else {
                    const auto& room = m_mapRoom[_ready.roomid()];
                    if (room->m_mapPlayer.find(_ready.userid()) == room->m_mapPlayer.end()) { break; }
                    auto& players = room->m_mapPlayer;
                    players[_ready.userid()]->m_state = 1;
                }
            } while (0);
            rsp.set_return_code(1);
            tcp_send(token, pb_common::protocol_code::protocol_ready_response, rsp.SerializeAsString());
        });
        register_tcp_callback(pb_common::protocol_code::protocol_leave_room, [&](LONG token, int protocol, const std::string& real_data) {
            pb_common::data_user_leave_room _lv;
            if (!_lv.ParseFromString(real_data)) { return; }
            pb_common::data_user_leave_room_response rsp;
            int userid = _lv.userid();
            {
                std::lock_guard<std::mutex> lk(lock_room);
                for (auto& iter : m_mapRoom) {
                    auto& players = iter.second->m_mapPlayer;
                    if (players.find(userid) != players.end()) {
                        rsp.set_userid(userid);
                        rsp.set_roomid(iter.first);
                        for (auto& it : players) {
                            tcp_send(it.second->m_token, pb_common::protocol_code::protocol_leave_room_response, rsp.SerializeAsString());
                        }
                        players.erase(userid);
                    }
                }
            }
        });
        register_udp_callback(pb_common::protocol_code::protocol_frame, [&](const std::string& data, const udp::endpoint& ed) {
            pb_common::data_ope frame;
            if (!frame.ParseFromString(data)) { return; }
            auto userid = frame.userid();
            std::lock_guard<std::mutex> lk(lock_room);
            for (auto& iter : m_mapRoom) {
                if (iter.second->game_start && iter.second->m_mapPlayer.find(userid) != iter.second->m_mapPlayer.end()) {
                    iter.second->input_frame(userid, frame.frameid(), frame);
                    break;
                }
            }
        });
        register_udp_callback(pb_common::protocol_code::protocol_ping, [&](const std::string& data, const udp::endpoint& ed) {
            pb_common::data_ping ping;
            if (!ping.ParseFromString(data)) { return; }
            pb_common::data_pong pong;
            pong.set_userid(ping.userid());
            udp_send(ping.userid(), pb_common::protocol_code::protocol_pong, ping.ByteSizeLong(), ping.SerializeAsString());
            update_udp_session(ping.userid(), ed);
        });
    }

    void tcp_session_close(LONG token)
    {
        int userid = -1;
        {
            std::lock_guard<std::mutex> lk(lock_token);
            if (m_mapTokenUserId.find(token) != m_mapTokenUserId.end()) {
                userid = m_mapTokenUserId[token];
                m_mapTokenUserId.erase(token);
            }
        }
        if (-1 == userid) { return; }
        {
            std::lock_guard<std::mutex> lk(lock_room);
            auto iter = m_mapRoom.begin();
            while (iter != m_mapRoom.end()) {
                auto& players = iter->second->m_mapPlayer;
                if (players.find(userid) != players.end()) {
                    pb_common::data_tcp_close rsp;
                    rsp.set_userid(userid);
                    rsp.set_token(token);
                    for (auto& it : players) {
                        tcp_send(it.second->m_token, pb_common::protocol_code::protocol_tcp_close, rsp.SerializeAsString());
                    }
                    players.erase(userid);
                }
                if (players.size() <= 0) {
                    iter = m_mapRoom.erase(iter);
                }
                else {
                    iter++;
                }
            }
        }
    }

    void handle_tcp_data(LONG token, int protocol, const std::string& real_data)
    {
        if (m_tcpProtocalCallback.find(protocol) != m_tcpProtocalCallback.end()) {
            m_tcpProtocalCallback[protocol](token, protocol, real_data);
        }
    }

    void handle_udp_data(const std::string& data, const udp::endpoint& ed)
    {
        pb_common::data_head head;
        if (!head.ParsePartialFromString(data)) { return; }
        int protocol = head.protocol_code();
        if (m_udpProtocalCallback.find(protocol) != m_udpProtocalCallback.end()) {
            m_udpProtocalCallback[protocol](head.data_str(), ed);
        }
    }

    void register_tcp_callback(int id, std::function<void(LONG, int, const std::string&)> cb)
    {
        m_tcpProtocalCallback.insert(std::make_pair(id, cb));
    }

    void register_udp_callback(int id, std::function<void(const std::string&, const udp::endpoint&)> cb)
    {
        m_udpProtocalCallback.insert(std::make_pair(id, cb));
    }

public:
    std::unique_ptr<std::thread> m_pLogicThread;
    RedisPool* m_pRedisPool;
    std::mutex lock_room;
    int m_nIncrRoomId;
    std::map<int, std::shared_ptr<gameroom>> m_mapRoom;
    std::map<int, std::function<void(LONG, int, const std::string&)>> m_tcpProtocalCallback;
    std::map<int, std::function<void(const std::string&, const udp::endpoint&)>> m_udpProtocalCallback;
    std::mutex lock_token;
    std::map<LONG, int> m_mapTokenUserId;
};

void gameroom::start_game(gameserver* pServer, int playercount) {
    if (!pServer) { return; }
    if (!game_start) {
        game_start = true;
        pb_common::data_begin begin;
        begin.set_rand_seed((uint32_t)time(nullptr));
        for (auto& iter : m_mapPlayer) {
            begin.mutable_userids()->Add(iter.first);
        }
        for (auto& iter : m_mapPlayer) {
            pServer->tcp_send(iter.second->m_token, pb_common::protocol_code::protocol_begin, begin.SerializeAsString());
        }
    }
    if (game_start) {
        std::lock_guard<std::mutex> lk(lock_frames);
        if (frame_sync.size() < playercount) { return; }
		auto ms = getMs();
        int frameid = currentFrame++;
        for (auto& it : m_mapPlayer) {
            std::string strLog = "";
            int userid = it.second->m_userid;
            pb_common::data_frames frames;
            auto begin_frame = frame_sync[userid] < 0 ? 0 : frame_sync[userid];
            for (auto i = begin_frame+1; i <= frameid; ++i) {
                auto frame = frames.add_frames();
                frame->set_frameid(i);
                strLog += std::to_string(i);
                strLog += std::string("#");
                if (frames_.find(i) != frames_.end()) {
                    for (auto& iter : frames_[i]) {
                        strLog += std::to_string(iter.first);
                        strLog += std::string("|");
                        auto user_frame = frame->add_frames();
                        if (user_frame) {
                            for (auto& it : iter.second) {
                                user_frame->set_userid(iter.first);
                                user_frame->set_frameid(it.first);
                                std::string strSub = "";
                                for (auto& itIn : it.second.opecode()) {
                                    auto opecode = user_frame->add_opecode();
                                    if (opecode) {
                                        opecode->set_opetype(itIn.opetype());
                                        opecode->set_opestring(itIn.opestring());
                                        strSub += std::to_string(itIn.opetype());
                                        strSub += std::string(">");
                                        strSub += std::string(itIn.opestring());
                                        strSub += std::string("<");
                                    }
                                }
                                strLog += std::to_string(it.first);
                                strLog += std::string(":");
                                strLog += strSub;
                                strLog += std::string("&");
                            }
                        }
                    }
                }
            }
            bool pkLoss = (rand() % 5) == 0 && false;
            if (!pkLoss) {
                pServer->udp_send(userid, pb_common::protocol_code::protocol_frame, frames.ByteSizeLong(), frames.SerializeAsString());
            }
            if (strLog != "") {
                if (!pkLoss) {
                    printf_s("[send] server send to userid %d frame info %s\n", userid, strLog.c_str());
                }
                else {
                    printf_s("[send] !!loss!! server send to userid %d frame info %s\n", userid, strLog.c_str());
                }
            }
        }
    }
}

int main()
{
    GOOGLE_PROTOBUF_VERIFY_VERSION;

    try {
        std::shared_ptr<asio::io_service> io_service = std::make_shared<asio::io_service>();
        gameserver s("127.0.0.1", 8888, 8889, io_service);
        auto ch = getchar();
    }
    catch (std::exception& e) {
        std::cerr << "Exception: " << e.what() << "\n";
    }

    google::protobuf::ShutdownProtobufLibrary();
    return 0;
}
