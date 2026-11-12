#pragma once

#include <cstdint>
#include <string>

/**
 * Windows 下最小化的 PCM 输出（waveOut）。
 *
 * 内部结构：
 *   write()  —— 解码线程调用，只把 PCM 塞进环形缓冲，永不阻塞
 *   feeder   —— 独立线程按设备节奏把环形缓冲喂给 waveOut（真正的阻塞点）
 *
 * 这样音频不会再拖慢视频解码线程，也不会因为瞬时缓冲满而丢音。
 */
class AudioSinkWin32
{
public:
    struct Impl;

    AudioSinkWin32();
    ~AudioSinkWin32();

    bool open(int sampleRate = 44100, int channels = 2);
    void close();
    bool isOpen() const;

    /** 非阻塞：把 PCM 放进环形缓冲（frames 为每声道采样数）。 */
    bool write(const int16_t* pcm, int frames);

    void pause(bool paused);

    /** 停止并清空缓冲，设备播放位置归零。 */
    void reset();

    /** 已经真正播放出去的时长（秒）。 */
    double playedSeconds() const;

    /** 打开时实际使用的设备名（诊断用）。 */
    const std::string& deviceName() const;

    /** 环形缓冲溢出丢弃的采样数。 */
    uint64_t droppedSamples() const;

    /** waveOutWrite 失败次数。 */
    uint64_t writeFailures() const;

    /** 设备缓冲被放空（欠载）的次数，听感上就是卡一下。 */
    uint64_t underrunCount() const;

private:
    void feederLoop();
    void feedBlocking(const int16_t* pcm, int frames);

    Impl* _impl;
};
