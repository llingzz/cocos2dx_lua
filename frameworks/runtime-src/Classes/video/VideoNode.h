#pragma once

#include "cocos2d.h"

#include <functional>
#include <memory>

namespace video
{
class VideoPlayerImpl;
struct VideoFrame;
}

/**
 * 场景内的视频节点：解码在后台线程，主线程每帧把 RGBA 上传到 Texture2D。
 *
 * 用法（Lua）：
 *   local video = cc.VideoNode:create("video/intro.mp4")
 *   video:setPosition(...)
 *   video:addEventListener(function(sender, event) end)
 *   layer:addChild(video)
 *   video:play()
 */
class VideoNode : public cocos2d::Node
{
public:
    static VideoNode* create(const std::string& path);
    bool init(const std::string& path);

    void play();
    void pause();
    void resume();
    void stop();
    void seek(float seconds);

    void setLoop(bool loop);
    bool isPlaying() const;

    float getDuration() const;
    float getCurrentTime();
    float getVideoWidth() const;
    float getVideoHeight() const;

    unsigned int getDecodedFrames() const;
    unsigned int getRenderedFrames() const;
    unsigned int getSendErrors() const;
    unsigned int getUpdateCount() const;
    float getUploadMs() const;
    unsigned int getPushedFrames() const;
    unsigned int getDroppedFrames() const;
    unsigned int getEmptyPolls() const;
    unsigned int getAudioDrops() const;
    unsigned int getAudioWriteFailures() const;
    unsigned int getAudioUnderruns() const;

    void setVolume(float volume);
    void setEventCallback(const std::function<void(int)>& callback);

    virtual void onEnter() override;
    virtual void onExit() override;

    VideoNode();
    virtual ~VideoNode();

private:
    void onFrameUpdate(float dt);
    void createTexture(int width, int height);
    void destroyTexture();

    std::unique_ptr<video::VideoPlayerImpl> _player;
    cocos2d::Texture2D* _texture = nullptr;
    cocos2d::Sprite* _sprite = nullptr;
    int _textureWidth = 0;
    int _textureHeight = 0;
    int _videoWidth = 0;
    int _videoHeight = 0;
    float _renderScale = 1.0f;
    double _uploadMs = 0.0;
    bool _wasPlaying = false;
    bool _scheduled = false;
    unsigned int _updateCount = 0;
    std::function<void(int)> _eventCallback;
};
