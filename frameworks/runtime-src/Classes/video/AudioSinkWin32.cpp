#include "AudioSinkWin32.h"

#if defined(_WIN32)

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <mmsystem.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <deque>
#include <mutex>
#include <thread>
#include <vector>

#pragma comment(lib, "winmm.lib")

namespace
{
const int kBufferCount = 8;
const int kFramesPerBuffer = 2048;   // 44.1k 下约 46ms，8 块约 370ms
const int kFeederChunk = 1024;
}

struct AudioSinkWin32::Impl
{
    HWAVEOUT hwo = nullptr;
    WAVEHDR hdr[kBufferCount] = {};
    std::vector<int16_t> buffers[kBufferCount];
    std::vector<int> freeList;

    std::mutex mutex;                 // 保护 hwo / freeList / hdr / flags
    std::condition_variable cv;

    // PCM 环形缓冲（解码线程 -> feeder 线程）
    std::mutex ringMutex;
    std::condition_variable ringCv;
    std::deque<int16_t> ring;
    size_t ringCapacitySamples = 0;

    std::thread feeder;
    std::atomic<bool> feederRunning{false};

    std::atomic<uint64_t> ringDrops{0};
    std::atomic<uint64_t> writeFailures{0};
    std::atomic<uint64_t> underruns{0};
    bool fedOnce = false;

    std::string deviceName;

    bool flushing = false;
    bool closed = false;
    int sampleRate = 44100;
    int channels = 2;
};

static void CALLBACK audioSinkWaveOutProc(HWAVEOUT, UINT msg, DWORD_PTR instance, DWORD_PTR param1, DWORD_PTR)
{
    if (msg != WOM_DONE)
        return;

    auto* impl = reinterpret_cast<AudioSinkWin32::Impl*>(instance);
    auto* hdr = reinterpret_cast<WAVEHDR*>(param1);

    std::lock_guard<std::mutex> lock(impl->mutex);
    if (impl->closed)
        return;

    const int index = static_cast<int>(hdr->dwUser);
    if (std::find(impl->freeList.begin(), impl->freeList.end(), index) == impl->freeList.end())
        impl->freeList.push_back(index);
    impl->cv.notify_all();
}

AudioSinkWin32::AudioSinkWin32()
    : _impl(new Impl())
{
}

AudioSinkWin32::~AudioSinkWin32()
{
    close();
    delete _impl;
    _impl = nullptr;
}

bool AudioSinkWin32::open(int sampleRate, int channels)
{
    if (!_impl || _impl->hwo)
        return _impl != nullptr;

    _impl->sampleRate = sampleRate;
    _impl->channels = channels;

    WAVEFORMATEX wf = {};
    wf.wFormatTag = WAVE_FORMAT_PCM;
    wf.nChannels = static_cast<WORD>(channels);
    wf.nSamplesPerSec = static_cast<DWORD>(sampleRate);
    wf.wBitsPerSample = 16;
    wf.nBlockAlign = static_cast<WORD>(channels * 2);
    wf.nAvgBytesPerSec = wf.nSamplesPerSec * wf.nBlockAlign;

    MMRESULT result = waveOutOpen(&_impl->hwo, WAVE_MAPPER, &wf,
                                 reinterpret_cast<DWORD_PTR>(&audioSinkWaveOutProc),
                                 reinterpret_cast<DWORD_PTR>(_impl),
                                 CALLBACK_FUNCTION);
    if (result != MMSYSERR_NOERROR)
    {
        _impl->hwo = nullptr;
        return false;
    }

    UINT deviceId = 0;
    if (waveOutGetID(_impl->hwo, &deviceId) == MMSYSERR_NOERROR)
    {
        WAVEOUTCAPSA caps = {};
        if (waveOutGetDevCapsA(deviceId, &caps, sizeof(caps)) == MMSYSERR_NOERROR)
            _impl->deviceName = caps.szPname;
    }

    for (int i = 0; i < kBufferCount; ++i)
    {
        _impl->buffers[i].resize(static_cast<size_t>(kFramesPerBuffer) * channels);

        WAVEHDR& h = _impl->hdr[i];
        std::memset(&h, 0, sizeof(h));
        h.lpData = reinterpret_cast<LPSTR>(_impl->buffers[i].data());
        h.dwBufferLength = static_cast<DWORD>(_impl->buffers[i].size() * sizeof(int16_t));
        h.dwUser = static_cast<DWORD_PTR>(i);

        if (waveOutPrepareHeader(_impl->hwo, &h, sizeof(WAVEHDR)) != MMSYSERR_NOERROR)
        {
            close();
            return false;
        }
        _impl->freeList.push_back(i);
    }

    _impl->ringCapacitySamples = static_cast<size_t>(sampleRate) * channels * 4;   // 4 秒
    _impl->feederRunning = true;
    _impl->feeder = std::thread(&AudioSinkWin32::feederLoop, this);

    return true;
}

void AudioSinkWin32::close()
{
    if (!_impl || !_impl->hwo)
        return;

    {
        std::lock_guard<std::mutex> lock(_impl->mutex);
        _impl->closed = true;
    }
    _impl->feederRunning = false;
    _impl->cv.notify_all();
    _impl->ringCv.notify_all();

    if (_impl->feeder.joinable())
        _impl->feeder.join();

    waveOutReset(_impl->hwo);
    waveOutClose(_impl->hwo);
    _impl->hwo = nullptr;

    {
        std::lock_guard<std::mutex> lock(_impl->mutex);
        _impl->freeList.clear();
        _impl->closed = false;
        _impl->flushing = false;
    }
    {
        std::lock_guard<std::mutex> lock(_impl->ringMutex);
        _impl->ring.clear();
    }
}

bool AudioSinkWin32::isOpen() const
{
    return _impl != nullptr && _impl->hwo != nullptr;
}

bool AudioSinkWin32::write(const int16_t* pcm, int frames)
{
    if (!_impl || !_impl->hwo || !pcm || frames <= 0)
        return false;

    const size_t samples = static_cast<size_t>(frames) * _impl->channels;

    std::lock_guard<std::mutex> lock(_impl->ringMutex);

    // 环形缓冲满了就丢最旧的，保证低延迟而不是无限增长
    if (_impl->ring.size() + samples > _impl->ringCapacitySamples)
    {
        const size_t overflow = _impl->ring.size() + samples - _impl->ringCapacitySamples;
        const size_t drop = std::min(overflow, _impl->ring.size());
        _impl->ring.erase(_impl->ring.begin(), _impl->ring.begin() + static_cast<std::ptrdiff_t>(drop));
        _impl->ringDrops.fetch_add(drop);
    }

    _impl->ring.insert(_impl->ring.end(), pcm, pcm + samples);
    _impl->ringCv.notify_one();
    return true;
}

void AudioSinkWin32::feederLoop()
{
    std::vector<int16_t> chunk;

    while (_impl->feederRunning)
    {
        size_t frames = 0;
        {
            std::unique_lock<std::mutex> lock(_impl->ringMutex);
            _impl->ringCv.wait_for(lock, std::chrono::milliseconds(20), [this] {
                return !_impl->feederRunning ||
                       _impl->ring.size() >= static_cast<size_t>(kFeederChunk) * _impl->channels;
            });

            if (!_impl->feederRunning && _impl->ring.size() < static_cast<size_t>(kFeederChunk) * _impl->channels)
                break;

            frames = std::min(_impl->ring.size() / _impl->channels,
                              static_cast<size_t>(kFramesPerBuffer));
            if (frames == 0)
            {
                // 设备把缓冲放空了还没有数据 => 欠载（听感就是卡一下）
                if (_impl->fedOnce)
                    _impl->underruns.fetch_add(1);
                continue;
            }
            _impl->fedOnce = true;

            chunk.assign(_impl->ring.begin(),
                         _impl->ring.begin() + static_cast<std::ptrdiff_t>(frames * _impl->channels));
            _impl->ring.erase(_impl->ring.begin(),
                              _impl->ring.begin() + static_cast<std::ptrdiff_t>(frames * _impl->channels));
        }

        feedBlocking(chunk.data(), static_cast<int>(frames));
    }
}

void AudioSinkWin32::feedBlocking(const int16_t* pcm, int frames)
{
    if (!_impl || !_impl->hwo || frames <= 0)
        return;

    std::unique_lock<std::mutex> lock(_impl->mutex);

    // 只有 feeder 线程会阻塞在这里；没有超时，避免因为设备抖动而丢数据
    _impl->cv.wait(lock, [this] {
        return _impl->closed || _impl->flushing || !_impl->freeList.empty();
    });

    if (_impl->closed || _impl->flushing || _impl->freeList.empty())
        return;

    const int index = _impl->freeList.back();
    _impl->freeList.pop_back();

    const int maxFrames = static_cast<int>(_impl->buffers[index].size() / _impl->channels);
    const int writeFrames = std::min(frames, maxFrames);
    std::memcpy(_impl->buffers[index].data(), pcm,
                static_cast<size_t>(writeFrames) * _impl->channels * sizeof(int16_t));

    WAVEHDR& h = _impl->hdr[index];
    h.dwBufferLength = static_cast<DWORD>(writeFrames * _impl->channels * sizeof(int16_t));
    h.dwFlags &= ~WHDR_DONE;

    if (waveOutWrite(_impl->hwo, &h, sizeof(WAVEHDR)) != MMSYSERR_NOERROR)
    {
        _impl->freeList.push_back(index);
        _impl->writeFailures.fetch_add(1);
    }
}

void AudioSinkWin32::pause(bool paused)
{
    if (!_impl || !_impl->hwo)
        return;

    if (paused)
        waveOutPause(_impl->hwo);
    else
        waveOutRestart(_impl->hwo);
}

void AudioSinkWin32::reset()
{
    if (!_impl || !_impl->hwo)
        return;

    {
        std::lock_guard<std::mutex> lock(_impl->ringMutex);
        _impl->ring.clear();
    }

    HWAVEOUT handle = _impl->hwo;
    {
        std::unique_lock<std::mutex> lock(_impl->mutex);
        _impl->flushing = true;
        _impl->cv.notify_all();
    }

    // waveOutReset 会同步回调 WOM_DONE，因此不能持锁调用。
    waveOutReset(handle);

    {
        std::lock_guard<std::mutex> lock(_impl->mutex);
        _impl->freeList.clear();
        for (int i = 0; i < kBufferCount; ++i)
        {
            _impl->hdr[i].dwBufferLength = static_cast<DWORD>(_impl->buffers[i].size() * sizeof(int16_t));
            _impl->hdr[i].dwFlags &= ~WHDR_DONE;
            _impl->freeList.push_back(i);
        }
        _impl->flushing = false;
    }
    _impl->cv.notify_all();
}

double AudioSinkWin32::playedSeconds() const
{
    if (!_impl || !_impl->hwo)
        return 0.0;

    MMTIME time = {};
    time.wType = TIME_SAMPLES;
    if (waveOutGetPosition(_impl->hwo, &time, sizeof(time)) != MMSYSERR_NOERROR)
        return 0.0;

    if (time.wType == TIME_SAMPLES)
        return static_cast<double>(time.u.sample) / static_cast<double>(_impl->sampleRate);

    if (time.wType == TIME_MS)
        return static_cast<double>(time.u.ms) / 1000.0;

    if (time.wType == TIME_BYTES)
    {
        const double bytesPerSecond = static_cast<double>(_impl->sampleRate) * _impl->channels * 2;
        return static_cast<double>(time.u.cb) / bytesPerSecond;
    }

    return 0.0;
}

const std::string& AudioSinkWin32::deviceName() const
{
    static const std::string kEmpty;
    return _impl ? _impl->deviceName : kEmpty;
}

uint64_t AudioSinkWin32::droppedSamples() const
{
    return _impl ? _impl->ringDrops.load() : 0;
}

uint64_t AudioSinkWin32::writeFailures() const
{
    return _impl ? _impl->writeFailures.load() : 0;
}

uint64_t AudioSinkWin32::underrunCount() const
{
    return _impl ? _impl->underruns.load() : 0;
}

#else   // 非 Windows 平台：先留空实现，后续接 OpenSL ES / AudioUnit

struct AudioSinkWin32::Impl
{
};

AudioSinkWin32::AudioSinkWin32() : _impl(nullptr) {}
AudioSinkWin32::~AudioSinkWin32() {}
bool AudioSinkWin32::open(int, int) { return false; }
void AudioSinkWin32::close() {}
bool AudioSinkWin32::isOpen() const { return false; }
bool AudioSinkWin32::write(const int16_t*, int) { return false; }
void AudioSinkWin32::pause(bool) {}
void AudioSinkWin32::reset() {}
double AudioSinkWin32::playedSeconds() const { return 0.0; }
const std::string& AudioSinkWin32::deviceName() const { static const std::string kEmpty; return kEmpty; }
uint64_t AudioSinkWin32::droppedSamples() const { return 0; }
uint64_t AudioSinkWin32::writeFailures() const { return 0; }
uint64_t AudioSinkWin32::underrunCount() const { return 0; }
void AudioSinkWin32::feederLoop() {}
void AudioSinkWin32::feedBlocking(const int16_t*, int) {}

#endif
