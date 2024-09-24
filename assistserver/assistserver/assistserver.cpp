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
    session(std::shared_ptr<asio::ip::tcp::socket> socket, asio::io_service::strand strand, LONG token, std::function<void(LONG)> cbRemove) :
        socket_(socket),
        strand_(strand),
        tokenid(token),
        m_cbRemove(cbRemove)
    {
        memset(data_, 0, sizeof(data_));
    }

    void start() {
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
        char head[12] = { 0 };
        sprintf_s(head, sizeof(head), "%08d", pb_head.ByteSizeLong());
        write(std::string(head) + pb_head.SerializeAsString());
    }

private:
    void hander_data(const std::string& data) {
        pb_common::data_head head;
        auto ret = head.ParseFromString(data);
        if (!ret) {
            return;
        }
        int idx = data.size() - head.data_len();
        std::string real_data = data.substr(idx, data.size() - 1);
        switch (head.protocol_code()) {
        case 0:
        {
            pb_common::req_test test;
            ret = test.ParseFromString(real_data);
            if (!ret) {
                break;
            }
            printf("%s n1 %d s1 %s arr %d|%d|%d|%d\n", __FUNCTION__, test.n1(), test.s1().c_str(),
                test.arr().at(0), test.arr().at(1), test.arr().at(2), test.arr().at(3));
            pb_common::res_test res;
            res.set_r1(test.n1());
            res.set_s1(test.s1());
            send(1, res.SerializeAsString());
        }
        default:
            break;
        }
    }

    void do_read() {
        auto self(shared_from_this());
        asio::async_read(*socket_, asio::buffer(data_, head),
            asio::bind_executor(strand_,
                [this, self](asio::error_code ec, std::size_t length)
                {
                    if (!ec) {
                        auto len = atoi(data_);
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

    LONG tokenid;
    std::shared_ptr<asio::ip::tcp::socket> socket_;
    asio::io_service::strand strand_;
    enum { max_length = 1024, head = 8 };
    char data_[max_length];
    std::mutex lock;
    std::deque<std::string> write_msgs_;
    std::function<void(LONG)> m_cbRemove;
};

/*协议格式：数据长度(8字符)|数据*/
class server
{
public:
    server(std::string strIp, int port)
    {
        m_lTokenId = 0;
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
        for (auto i = 0; i < 1000; ++i) {
            do_accept();
        }
    }

    void remove_session(LONG token) {
        if (m_mapSessions.find(token) != m_mapSessions.end()) {
            m_mapSessions.erase(token);
        }
    }

private:
    void do_accept()
    {
        auto socket_ = std::make_shared<asio::ip::tcp::socket>(*m_pContext);
        m_pAcceptor->async_accept(*socket_,
            [this,socket_](asio::error_code ec)
            {
                if (!ec) {
                    auto token = m_lTokenId++;
                    const auto& strand = m_pStrands[token % m_pStrands.size()];
                    m_mapSessions[token] = std::make_shared<session>(socket_, *strand, token,
                        [this](LONG token) {
                            if (m_mapSessions.find(token) != m_mapSessions.end()) {
                                m_mapSessions.erase(token);
                            }
                        }
                    );
                    m_mapSessions[token]->start();
                }
                do_accept();
            }
        );
    }

    LONG m_lTokenId;
    std::unique_ptr<tcp::acceptor> m_pAcceptor;
    std::vector<std::unique_ptr<asio::io_service::strand>> m_pStrands;
    std::unique_ptr<asio::io_service> m_pContext;
    std::unique_ptr<std::thread> m_pThread;
    std::map<LONG, std::shared_ptr<session>> m_mapSessions;
};

class gameserver : public server {
public:
    gameserver(std::string strIp, int port) :
        server(strIp, port) {

    }
};

int main()
{
    GOOGLE_PROTOBUF_VERIFY_VERSION;

    try {
        gameserver s("127.0.0.1", 8888);
        auto ch = getchar();
    }
    catch (std::exception& e) {
        std::cerr << "Exception: " << e.what() << "\n";
    }

    google::protobuf::ShutdownProtobufLibrary();
    return 0;
}
