#include "VideoPlayerImpl.h"

#include "AudioSinkWin32.h"

#include "cocos2d.h"

#if defined(_WIN32)
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <mmsystem.h>
#pragma comment(lib, "winmm.lib")
#endif

extern "C" {
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/avutil.h"
#include "libavutil/channel_layout.h"
#include "libavutil/error.h"
#include "libavutil/pixfmt.h"
#include "libswresample/swresample.h"
#include "libswscale/swscale.h"
}

using namespace cocos2d;

namespace video
{
namespace
{
double steadySeconds()
{
    return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();
}
}  // namespace

VideoPlayerImpl::VideoPlayerImpl()
{
    _bridge.reset(new Bridge());
    _resumeTime = std::chrono::steady_clock::now();
}

VideoPlayerImpl::~VideoPlayerImpl()
{
    if (_bridge)
        _bridge->alive = false;

    stop();

    if (_sink)
    {
        _sink->close();
        _sink.reset();
    }
    if (_sws)
    {
        sws_freeContext(_sws);
        _sws = nullptr;
    }
    if (_swr)
        swr_free(&_swr);
    if (_frame)
        av_frame_free(&_frame);
    if (_actx)
        avcodec_free_context(&_actx);
    if (_vctx)
        avcodec_free_context(&_vctx);
    if (_fmt)
        avformat_close_input(&_fmt);
}

bool VideoPlayerImpl::open(const std::string& path)
{
    if (_fmt)
        return true;

    int ret = avformat_open_input(&_fmt, path.c_str(), nullptr, nullptr);
    if (ret < 0)
    {
        CCLOG("VideoPlayer: avformat_open_input failed (%d) for %s", ret, path.c_str());
        _fmt = nullptr;
        return false;
    }

    if (avformat_find_stream_info(_fmt, nullptr) < 0)
    {
        CCLOG("VideoPlayer: avformat_find_stream_info failed");
        avformat_close_input(&_fmt);
        return false;
    }

    _videoIndex = av_find_best_stream(_fmt, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    if (_videoIndex < 0)
    {
        CCLOG("VideoPlayer: no video stream");
        avformat_close_input(&_fmt);
        return false;
    }

    AVStream* videoStream = _fmt->streams[_videoIndex];
    const AVCodec* videoCodec = avcodec_find_decoder(videoStream->codecpar->codec_id);
    if (!videoCodec)
    {
        CCLOG("VideoPlayer: unsupported video codec");
        avformat_close_input(&_fmt);
        return false;
    }

    _vctx = avcodec_alloc_context3(videoCodec);
    if (!_vctx)
        return false;
    avcodec_parameters_to_context(_vctx, videoStream->codecpar);
    _vctx->thread_count = 2;
    _vctx->thread_type = FF_THREAD_FRAME | FF_THREAD_SLICE;
    if (avcodec_open2(_vctx, videoCodec, nullptr) < 0)
    {
        CCLOG("VideoPlayer: avcodec_open2(video) failed");
        return false;
    }

    _videoTimeBase = av_q2d(videoStream->time_base);
    _width = videoStream->codecpar->width;
    _height = videoStream->codecpar->height;
    _duration = _fmt->duration != AV_NOPTS_VALUE ? static_cast<double>(_fmt->duration) / AV_TIME_BASE : 0.0;
    _startSec = _fmt->start_time != AV_NOPTS_VALUE ? static_cast<double>(_fmt->start_time) / AV_TIME_BASE : 0.0;

    _audioIndex = av_find_best_stream(_fmt, AVMEDIA_TYPE_AUDIO, -1, _videoIndex, nullptr, 0);
    if (_audioIndex >= 0)
    {
        // 按源采样率输出，避免 48k -> 44.1k -> 48k 的双重重采样
        const int sourceRate = _fmt->streams[_audioIndex]->codecpar->sample_rate;
        if (sourceRate > 0)
            _audioOutRate = sourceRate;
        initAudioDecoder();
    }

    _frame = av_frame_alloc();
    if (!_frame)
        return false;

    if (_audioIndex >= 0 && _actx && _swr)
    {
        _sink.reset(new AudioSinkWin32());
        _audioClock = _sink->open(_audioOutRate, 2);
        if (!_audioClock)
        {
            CCLOG("VideoPlayer: audio device open failed, fall back to system clock");
            _sink.reset();
        }
        else
        {
            CCLOG("VideoPlayer: audio device = %s", _sink->deviceName().c_str());
        }
    }

    return true;
}

void VideoPlayerImpl::setEventCallback(const EventCallback& callback)
{
    std::lock_guard<std::mutex> lock(_bridge->mutex);
    _bridge->callback = callback;
}

bool VideoPlayerImpl::initAudioDecoder()
{
    AVStream* audioStream = _fmt->streams[_audioIndex];
    const AVCodec* audioCodec = avcodec_find_decoder(audioStream->codecpar->codec_id);
    if (!audioCodec)
        return false;

    _actx = avcodec_alloc_context3(audioCodec);
    if (!_actx)
        return false;
    avcodec_parameters_to_context(_actx, audioStream->codecpar);
    if (avcodec_open2(_actx, audioCodec, nullptr) < 0)
    {
        CCLOG("VideoPlayer: avcodec_open2(audio) failed");
        avcodec_free_context(&_actx);
        return false;
    }

    _audioTimeBase = av_q2d(audioStream->time_base);

    if (_actx->ch_layout.nb_channels == 0)
        av_channel_layout_default(&_actx->ch_layout, 2);

    AVChannelLayout outLayout = {};
    av_channel_layout_default(&outLayout, 2);
    int ret = swr_alloc_set_opts2(&_swr, &outLayout, AV_SAMPLE_FMT_S16, _audioOutRate,
                                  &_actx->ch_layout, _actx->sample_fmt, _actx->sample_rate, 0, nullptr);
    av_channel_layout_uninit(&outLayout);
    if (ret < 0 || !_swr || swr_init(_swr) < 0)
    {
        CCLOG("VideoPlayer: swr init failed");
        if (_swr)
            swr_free(&_swr);
        return false;
    }
    return true;
}

void VideoPlayerImpl::play()
{
    if (!_fmt)
        return;

    if (_running)
    {
        if (_paused)
            resume();
        return;
    }

    _stopRequested = false;
    _paused = false;
    _playing = true;
    _running = true;
    {
        std::lock_guard<std::mutex> lock(_mutex);
        _pausedElapsed = 0.0;
        _resumeTime = std::chrono::steady_clock::now();
        _audioBase = 0.0;
        _videoBase = 0.0;
        _pendingAudioBase = true;
        _dropUntil = -1.0;
        _audioProbeLastPlayed = -1.0;
        _audioProbeLastMove = std::chrono::steady_clock::now();
        _frames.clear();
    }

    if (_sink && _sink->isOpen())
    {
        _sink->reset();
        _sink->pause(false);   // waveOutReset 不会解除之前的 waveOutPause
    }

    _seekTarget = 0.0;
    _seekRequested = true;

    _paceBaseWall = steadySeconds();
    _paceBasePts = 0.0;

#if defined(_WIN32)
    timeBeginPeriod(1);   // 1ms 定时器精度，避免 60fps 节拍被系统粒度拖成抖动
#endif

    _thread = std::thread(&VideoPlayerImpl::threadLoop, this);
    emit(EV_PLAYING);
}

void VideoPlayerImpl::pause()
{
    if (!_running || _paused)
        return;

    if (!_audioClock)
    {
        std::lock_guard<std::mutex> lock(_mutex);
        _pausedElapsed +=
            std::chrono::duration<double>(std::chrono::steady_clock::now() - _resumeTime).count();
    }

    _paused = true;
    if (_sink && _sink->isOpen())
        _sink->pause(true);
    _cv.notify_all();
    emit(EV_PAUSED);
}

void VideoPlayerImpl::resume()
{
    if (!_running || !_paused)
        return;

    {
        std::lock_guard<std::mutex> lock(_mutex);
        _resumeTime = std::chrono::steady_clock::now();
        _audioProbeLastPlayed = -1.0;
        _audioProbeLastMove = std::chrono::steady_clock::now();
    }
    _paused = false;
    if (_sink && _sink->isOpen())
        _sink->pause(false);
    _cv.notify_all();
    emit(EV_PLAYING);
}

void VideoPlayerImpl::stop()
{
    _stopRequested = true;
    _paused = false;
    _cv.notify_all();

    if (_thread.joinable())
        _thread.join();

#if defined(_WIN32)
    timeEndPeriod(1);
#endif

    if (_sink && _sink->isOpen())
        _sink->pause(true);

    _playing = false;
}

void VideoPlayerImpl::seek(double seconds)
{
    if (!_running)
        return;

    _seekTarget = seconds;
    _seekRequested = true;
    _cv.notify_all();
}

void VideoPlayerImpl::setLoop(bool loop)
{
    _loop = loop;
}

void VideoPlayerImpl::setVolume(float volume)
{
    if (volume < 0.0f)
        volume = 0.0f;
    if (volume > 1.0f)
        volume = 1.0f;
    _volume = volume;
}

bool VideoPlayerImpl::isPlaying() const
{
    return _running && _playing && !_paused;
}

double VideoPlayerImpl::clock()
{
    const auto now = std::chrono::steady_clock::now();
    std::lock_guard<std::mutex> lock(_mutex);

    const double systemClock = _videoBase + _pausedElapsed +
        (_paused ? 0.0 : std::chrono::duration<double>(now - _resumeTime).count());

    if (!_audioClock || !_sink)
        return systemClock;

    const double played = _sink->playedSeconds();

    if (_paused)
        return _audioBase + played;

    // 位置前进就认为音频时钟健康
    if (_audioProbeLastPlayed < 0.0 || played > _audioProbeLastPlayed + 0.002)
    {
        _audioProbeLastPlayed = played;
        _audioProbeLastMove = now;
    }
    else
    {
        const double stalled = std::chrono::duration<double>(now - _audioProbeLastMove).count();
        if (stalled > 0.35)
        {
            CCLOG("VideoPlayer: audio clock stalled at %.3fs for %.2fs, fall back to system clock",
                  played, stalled);
            _audioClock = false;
        }
    }

    // 设备瞬间把缓冲“播完”时位置会远超真实时间；位置严重落后同样不可信
    const double audioClock = _audioBase + played;
    if (_audioClock && (audioClock > systemClock + 0.35 || audioClock < systemClock - 0.5))
    {
        CCLOG("VideoPlayer: audio clock %.3fs vs system %.3fs, fall back to system clock",
              audioClock, systemClock);
        _audioClock = false;
    }

    return _audioClock ? audioClock : systemClock;
}

bool VideoPlayerImpl::takeFrame(double /*now*/, std::shared_ptr<VideoFrame>& out)
{
    std::lock_guard<std::mutex> lock(_mutex);

    if (_frames.empty())
    {
        ++_emptyPolls;
        return false;
    }

    out = _frames.back();
    _frames.clear();
    ++_renderedFrames;
    return true;
}

void VideoPlayerImpl::threadLoop()
{
    AVPacket* packet = av_packet_alloc();
    if (!packet)
    {
        _running = false;
        _playing = false;
        emit(EV_ERROR);
        return;
    }

    while (!_stopRequested)
    {
        if (_paused)
        {
            std::unique_lock<std::mutex> lock(_mutex);
            const auto pausedAt = std::chrono::steady_clock::now();
            while (_paused && !_stopRequested)
                _cv.wait_for(lock, std::chrono::milliseconds(50));
            if (_stopRequested)
                break;

            // shift the pacing base by the paused duration
            _paceBaseWall += std::chrono::duration<double>(
                                 std::chrono::steady_clock::now() - pausedAt).count();
        }

        if (_seekRequested.exchange(false))
        {
            if (!doSeek(_seekTarget))
            {
                CCLOG("VideoPlayer: seek failed");
                break;
            }
            continue;
        }

        int ret = av_read_frame(_fmt, packet);
        if (ret < 0)
        {
            if (ret == AVERROR_EOF)
            {
                handleEof();
                if (_loop && !_stopRequested)
                {
                    _seekTarget = 0.0;
                    _seekRequested = true;
                    continue;
                }
            }
            break;
        }

        if (packet->stream_index == _videoIndex)
            decodeVideo(packet);
        else if (_audioIndex >= 0 && packet->stream_index == _audioIndex)
            decodeAudio(packet);

        av_packet_unref(packet);
    }

    av_packet_free(&packet);
    _running = false;
    _playing = false;
    if (_sink && _sink->isOpen())
        _sink->pause(true);

    emit(_stopRequested ? EV_STOPPED : EV_COMPLETED);
}

void VideoPlayerImpl::handleEof()
{
    {
        std::lock_guard<std::mutex> lock(_mutex);
        if (!_frames.empty())
            return;   // 信箱里还有未显示的帧，先不冲刷
    }

    decodeVideo(nullptr);   // send nullptr 冲刷解码器
    if (_actx)
        decodeAudio(nullptr);
}

bool VideoPlayerImpl::doSeek(double seconds)
{
    if (seconds < 0.0)
        seconds = 0.0;
    if (_duration > 0.0 && seconds > _duration)
        seconds = _duration;

    const int64_t target = static_cast<int64_t>((seconds + _startSec) * AV_TIME_BASE);
    if (av_seek_frame(_fmt, -1, target, AVSEEK_FLAG_BACKWARD) < 0)
        return false;

    if (_vctx)
        avcodec_flush_buffers(_vctx);
    if (_actx)
        avcodec_flush_buffers(_actx);

    clearFrames();

    if (_sink && _sink->isOpen())
        _sink->reset();

    {
        std::lock_guard<std::mutex> lock(_mutex);
        _audioBase = seconds;
        _videoBase = seconds;
        _pausedElapsed = 0.0;
        _resumeTime = std::chrono::steady_clock::now();
        _pendingAudioBase = true;
        _dropUntil = seconds;
        _audioProbeLastPlayed = -1.0;
        _audioProbeLastMove = std::chrono::steady_clock::now();
        _paceBaseWall = steadySeconds();
        _paceBasePts = seconds;
    }
    return true;
}

void VideoPlayerImpl::clearFrames()
{
    std::lock_guard<std::mutex> lock(_mutex);
    _frames.clear();
    _cv.notify_all();
}

void VideoPlayerImpl::pushFrame(const std::shared_ptr<VideoFrame>& frame)
{
    // 单帧信箱：只保留最新一帧，主线程慢时自然丢帧，解码线程不等主线程
    std::lock_guard<std::mutex> lock(_mutex);
    _frames.clear();
    _frames.push_back(frame);
    ++_pushedFrames;
    _cv.notify_all();
}

void VideoPlayerImpl::paceTo(double pts)
{
    const double due = _paceBaseWall + (pts - _paceBasePts);
    for (;;)
    {
        if (_stopRequested || _paused)
            return;

        const double remain = due - steadySeconds();
        if (remain <= 0.0)
            return;   // 必须真的到期，提前返回会让整条时间线越跑越快

        // 到期时间按绝对时刻计算，睡过一点不会累积误差
        std::this_thread::sleep_for(std::chrono::microseconds(static_cast<long long>(remain * 1000000.0)));
    }
}

void VideoPlayerImpl::decodeVideo(AVPacket* packet)
{
    if (!_vctx)
        return;

    if (packet)
    {
        int ret = avcodec_send_packet(_vctx, packet);
        if (ret == AVERROR(EAGAIN))
        {
            // 解码器内部已满：先取走可用帧，再重发这一包，不能把包丢掉
            receiveVideoFrames();
            ret = avcodec_send_packet(_vctx, packet);
        }
        if (ret < 0 && ret != AVERROR_EOF)
        {
            const uint64_t errors = ++_sendErrors;
            if (errors <= 3)
                CCLOG("VideoPlayer: send_packet(video) failed: %d", ret);
            return;
        }
    }

    receiveVideoFrames();
}

void VideoPlayerImpl::receiveVideoFrames()
{
    for (;;)
    {
        int ret = avcodec_receive_frame(_vctx, _frame);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF)
            break;
        if (ret < 0)
            break;

        const int width = _frame->width;
        const int height = _frame->height;
        if (width <= 0 || height <= 0 || !ensureScaler(width, height, _frame->format))
        {
            av_frame_unref(_frame);
            continue;
        }

        const int outWidth = _renderWidth > 0 ? _renderWidth : width;
        const int outHeight = _renderHeight > 0 ? _renderHeight : height;

        auto frame = acquireFrame(outWidth, outHeight);

        uint8_t* dst[4] = { frame->rgba.data(), nullptr, nullptr, nullptr };
        int dstLines[4] = { outWidth * 4, 0, 0, 0 };
        sws_scale(_sws, _frame->data, _frame->linesize, 0, height, dst, dstLines);

        frame->pts = videoFramePts(_frame);
        ++_decodedFrames;
        if (frame->pts >= _dropUntil)
        {
            paceTo(frame->pts);
            pushFrame(frame);
        }
        else
        {
            ++_droppedFrames;
        }

        av_frame_unref(_frame);
    }
}

void VideoPlayerImpl::decodeAudio(AVPacket* packet)
{
    if (!_actx || !_swr || !_sink)
        return;

    if (packet)
    {
        int ret = avcodec_send_packet(_actx, packet);
        if (ret == AVERROR(EAGAIN))
        {
            receiveAudioFrames();
            ret = avcodec_send_packet(_actx, packet);
        }
        if (ret < 0 && ret != AVERROR_EOF)
        {
            const uint64_t errors = ++_sendErrors;
            if (errors <= 3)
                CCLOG("VideoPlayer: send_packet(audio) failed: %d", ret);
            return;
        }
    }

    receiveAudioFrames();
}

void VideoPlayerImpl::receiveAudioFrames()
{
    const int inputRate = _actx->sample_rate > 0 ? _actx->sample_rate : 44100;

    for (;;)
    {
        int ret = avcodec_receive_frame(_actx, _frame);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF)
            break;
        if (ret < 0)
            break;

        const double pts = audioFramePts(_frame);

        const int maxOut = static_cast<int>(av_rescale_rnd(
            swr_get_delay(_swr, inputRate) + _frame->nb_samples, _audioOutRate, inputRate, AV_ROUND_UP));
        if (maxOut <= 0)
        {
            av_frame_unref(_frame);
            continue;
        }

        // S16 / 立体声：每帧 2 声道 × 2 字节
        _pcm.resize(static_cast<size_t>(maxOut) * 2 * sizeof(int16_t));
        uint8_t* out[1] = { _pcm.data() };
        const uint8_t* const* input = (const uint8_t* const*)_frame->extended_data;
        const int got = swr_convert(_swr, out, maxOut, input, _frame->nb_samples);

        const bool dropped = (pts >= 0.0 && pts < _dropUntil);
        if (got > 0 && !dropped)
        {
            if (_pendingAudioBase)
            {
                std::lock_guard<std::mutex> lock(_mutex);
                if (pts >= 0.0)
                    _audioBase = pts;
                _pendingAudioBase = false;
            }

            const float volume = _volume.load();
            if (volume < 0.999f)
            {
                int16_t* samples = reinterpret_cast<int16_t*>(_pcm.data());
                for (int i = 0; i < got * 2; ++i)
                    samples[i] = static_cast<int16_t>(samples[i] * volume);
            }

            _sink->write(reinterpret_cast<const int16_t*>(_pcm.data()), got);
        }

        av_frame_unref(_frame);
    }
}

bool VideoPlayerImpl::ensureScaler(int width, int height, int pixelFormat)
{
    const int dstWidth = _renderWidth > 0 ? _renderWidth : width;
    const int dstHeight = _renderHeight > 0 ? _renderHeight : height;

    if (_sws && width == _swsWidth && height == _swsHeight && pixelFormat == _swsFormat &&
        dstWidth == _swsDstWidth && dstHeight == _swsDstHeight)
        return true;

    if (_sws)
    {
        sws_freeContext(_sws);
        _sws = nullptr;
    }

    const int flags = (dstWidth == width && dstHeight == height) ? SWS_POINT : SWS_BILINEAR;
    _sws = sws_getContext(width, height, static_cast<AVPixelFormat>(pixelFormat),
                          dstWidth, dstHeight, AV_PIX_FMT_RGBA,
                          flags, nullptr, nullptr, nullptr);
    if (!_sws)
        return false;

    _swsWidth = width;
    _swsHeight = height;
    _swsFormat = pixelFormat;
    _swsDstWidth = dstWidth;
    _swsDstHeight = dstHeight;
    return true;
}

std::shared_ptr<VideoFrame> VideoPlayerImpl::acquireFrame(int width, int height)
{
    // 复用已经没人引用的帧缓冲，避免每帧 4.5MB 的分配和清零
    for (auto& frame : _framePool)
    {
        if (frame.use_count() == 1 && frame->width == width && frame->height == height)
            return frame;
    }

    auto frame = std::make_shared<VideoFrame>();
    frame->width = width;
    frame->height = height;
    frame->rgba.resize(static_cast<size_t>(width) * height * 4);
    _framePool.push_back(frame);
    return frame;
}

double VideoPlayerImpl::videoFramePts(const AVFrame* frame) const
{
    int64_t ts = frame->best_effort_timestamp;
    if (ts == AV_NOPTS_VALUE)
        ts = frame->pts;
    if (ts == AV_NOPTS_VALUE)
        return -1.0;
    return static_cast<double>(ts) * _videoTimeBase - _startSec;
}

double VideoPlayerImpl::audioFramePts(const AVFrame* frame) const
{
    int64_t ts = frame->best_effort_timestamp;
    if (ts == AV_NOPTS_VALUE)
        ts = frame->pts;
    if (ts == AV_NOPTS_VALUE)
        return -1.0;
    return static_cast<double>(ts) * _audioTimeBase - _startSec;
}

uint64_t VideoPlayerImpl::audioDroppedSamples() const
{
    return _sink ? _sink->droppedSamples() : 0;
}

uint64_t VideoPlayerImpl::audioWriteFailures() const
{
    return _sink ? _sink->writeFailures() : 0;
}

uint64_t VideoPlayerImpl::audioUnderruns() const
{
    return _sink ? _sink->underrunCount() : 0;
}

void VideoPlayerImpl::emit(int event)
{
    auto bridge = _bridge;
    if (!bridge)
        return;

    Director::getInstance()->getScheduler()->performFunctionInCocosThread([bridge, event]() {
        if (!bridge->alive.load())
            return;
        std::lock_guard<std::mutex> lock(bridge->mutex);
        if (bridge->callback)
            bridge->callback(event);
    });
}

}  // namespace video
