#pragma once

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

struct AVFormatContext;
struct AVCodecContext;
struct AVFrame;
struct AVPacket;
struct SwsContext;
struct SwrContext;

class AudioSinkWin32;

namespace video
{

struct VideoFrame
{
    std::vector<uint8_t> rgba;
    int width = 0;
    int height = 0;
    double pts = 0.0;
};

/**
 * 解封装 + 解码 + 音频输出 + 主时钟。
 *
 * 线程模型：一个解码线程（demux/decode/音频阻塞写），GL 线程只通过
 * takeFrame() 取 RGBA 帧并上传纹理，不触碰 FFmpeg 上下文。
 * 时钟以音频设备已播采样为准；无音轨时退回 steady_clock。
 */
class VideoPlayerImpl
{
public:
    enum Event
    {
        EV_PLAYING = 0,
        EV_PAUSED = 1,
        EV_STOPPED = 2,
        EV_COMPLETED = 3,
        EV_ERROR = 4
    };

    typedef std::function<void(int)> EventCallback;

    VideoPlayerImpl();
    ~VideoPlayerImpl();

    bool open(const std::string& utf8Path);
    void setEventCallback(const EventCallback& callback);

    void play();
    void pause();
    void resume();
    void stop();
    void seek(double seconds);
    void setLoop(bool loop);
    void setVolume(float volume);

    bool isPlaying() const;
    bool isPaused() const { return _paused.load(); }
    bool isOpened() const { return _fmt != nullptr; }
    bool hasAudio() const { return _audioClock; }
    double duration() const { return _duration; }
    int videoWidth() const { return _width; }
    int videoHeight() const { return _height; }

    /** 转换/上传用的目标尺寸（0 表示按视频原始尺寸）。降采样能显著降低纹理上传开销。 */
    void setRenderSize(int width, int height) { _renderWidth = width; _renderHeight = height; }

    /** 主线程调用：按当前时钟取一帧（落后会丢帧，最多返回一帧）。 */
    bool takeFrame(double clock, std::shared_ptr<VideoFrame>& out);

    /** 当前媒体时钟（秒）。音频时钟停滞或异常时自动回退到系统时钟。 */
    double clock();

    uint64_t decodedFrames() const { return _decodedFrames.load(); }
    uint64_t renderedFrames() const { return _renderedFrames.load(); }
    uint64_t sendErrors() const { return _sendErrors.load(); }
    uint64_t pushedFrames() const { return _pushedFrames.load(); }
    uint64_t droppedFrames() const { return _droppedFrames.load(); }
    uint64_t emptyPolls() const { return _emptyPolls.load(); }
    uint64_t audioDroppedSamples() const;
    uint64_t audioWriteFailures() const;
    uint64_t audioUnderruns() const;

private:
    void threadLoop();
    void decodeVideo(AVPacket* packet);
    void decodeAudio(AVPacket* packet);
    void receiveVideoFrames();
    void receiveAudioFrames();
    void handleEof();
    bool doSeek(double seconds);
    void clearFrames();
    void pushFrame(const std::shared_ptr<VideoFrame>& frame);
    void paceTo(double pts);
    void emit(int event);
    bool ensureScaler(int width, int height, int pixelFormat);
    std::shared_ptr<VideoFrame> acquireFrame(int width, int height);
    bool initAudioDecoder();
    double videoFramePts(const AVFrame* frame) const;
    double audioFramePts(const AVFrame* frame) const;

    AVFormatContext* _fmt = nullptr;
    AVCodecContext* _vctx = nullptr;
    AVCodecContext* _actx = nullptr;
    AVFrame* _frame = nullptr;
    SwsContext* _sws = nullptr;
    SwrContext* _swr = nullptr;

    int _videoIndex = -1;
    int _audioIndex = -1;
    double _videoTimeBase = 0.0;
    double _audioTimeBase = 0.0;
    double _startSec = 0.0;
    double _duration = 0.0;
    int _width = 0;
    int _height = 0;
    int _swsWidth = 0;
    int _swsHeight = 0;
    int _swsFormat = -1;
    int _swsDstWidth = 0;
    int _swsDstHeight = 0;
    int _audioOutRate = 44100;
    int _renderWidth = 0;
    int _renderHeight = 0;
    bool _audioClock = false;

    std::unique_ptr<AudioSinkWin32> _sink;

    std::thread _thread;
    std::atomic<bool> _running{false};
    std::atomic<bool> _stopRequested{false};
    std::atomic<bool> _playing{false};
    std::atomic<bool> _paused{false};
    std::atomic<bool> _loop{false};
    std::atomic<bool> _seekRequested{false};
    std::atomic<float> _volume{1.0f};

    std::atomic<uint64_t> _decodedFrames{0};
    std::atomic<uint64_t> _renderedFrames{0};
    std::atomic<uint64_t> _sendErrors{0};
    std::atomic<uint64_t> _pushedFrames{0};
    std::atomic<uint64_t> _droppedFrames{0};
    std::atomic<uint64_t> _emptyPolls{0};

    double _seekTarget = 0.0;
    double _dropUntil = -1.0;

    // 解码线程按 pts 自控速（系统时钟为基准）
    double _paceBaseWall = 0.0;
    double _paceBasePts = 0.0;

    mutable std::mutex _mutex;
    std::condition_variable _cv;
    std::deque<std::shared_ptr<VideoFrame>> _frames;
    std::vector<std::shared_ptr<VideoFrame>> _framePool;
    std::vector<uint8_t> _pcm;

    double _audioBase = 0.0;
    double _videoBase = 0.0;
    double _pausedElapsed = 0.0;
    std::chrono::steady_clock::time_point _resumeTime;
    bool _pendingAudioBase = true;

    // 音频时钟健康检查：位置停滞或跳变过大时回退到系统时钟
    double _audioProbeLastPlayed = -1.0;
    std::chrono::steady_clock::time_point _audioProbeLastMove;

    struct Bridge
    {
        std::mutex mutex;
        EventCallback callback;
        std::atomic<bool> alive{true};
    };
    std::shared_ptr<Bridge> _bridge;
};

}  // namespace video
