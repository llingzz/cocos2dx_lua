#include "VideoNode.h"

#include "VideoPlayerImpl.h"

#include "platform/CCGL.h"

#include <chrono>
#include <cstdlib>
#include <vector>

USING_NS_CC;

namespace
{
const int kMaxPathLength = 1024;
}

VideoNode::VideoNode()
{
}

VideoNode::~VideoNode()
{
    if (_player)
    {
        _player->setEventCallback(nullptr);
        _player->stop();
        _player.reset();
    }
    _eventCallback = nullptr;
}

VideoNode* VideoNode::create(const std::string& path)
{
    VideoNode* node = new (std::nothrow) VideoNode();
    if (node && node->init(path))
    {
        node->autorelease();
        return node;
    }
    CC_SAFE_DELETE(node);
    return nullptr;
}

bool VideoNode::init(const std::string& path)
{
    if (!Node::init())
        return false;

    std::string fullPath = FileUtils::getInstance()->fullPathForFilename(path);
    if (fullPath.empty())
        fullPath = path;

    // FFmpeg 需要真实文件路径（相对路径依赖进程工作目录，靠不住）。
    char absolutePath[kMaxPathLength] = {0};
    if (_fullpath(absolutePath, fullPath.c_str(), kMaxPathLength) != nullptr)
        fullPath = absolutePath;

    _player.reset(new video::VideoPlayerImpl());
    if (!_player->open(fullPath))
    {
        CCLOG("VideoNode: open failed: %s", fullPath.c_str());
        _player.reset();
        return false;
    }

    _player->setEventCallback([this](int event) {
        if (_eventCallback)
            _eventCallback(event);
    });

    _videoWidth = _player->videoWidth();
    _videoHeight = _player->videoHeight();

    // 按窗口宽度降采样：纹理上传面积按比例下降，软渲染/集显下提升明显
    int renderWidth = _videoWidth;
    int renderHeight = _videoHeight;
    const Size winSize = Director::getInstance()->getWinSize();
    if (winSize.width > 0 && _videoWidth > static_cast<int>(winSize.width))
    {
        renderWidth = static_cast<int>(winSize.width);
        renderHeight = static_cast<int>(_videoHeight * (static_cast<float>(renderWidth) / _videoWidth));
        if (renderHeight <= 0)
            renderHeight = 1;
    }
    if (renderWidth <= 0 || renderHeight <= 0)
    {
        renderWidth = _videoWidth > 0 ? _videoWidth : 1;
        renderHeight = _videoHeight > 0 ? _videoHeight : 1;
    }

    _renderScale = static_cast<float>(_videoWidth) / renderWidth;
    _player->setRenderSize(renderWidth, renderHeight);

    createTexture(renderWidth, renderHeight);

    return true;
}

void VideoNode::createTexture(int width, int height)
{
    if (width <= 0 || height <= 0)
        return;

    destroyTexture();

    _texture = new (std::nothrow) Texture2D();
    if (!_texture)
        return;

    // initWithData 内部断言 dataLen > 0，不能传 nullptr 建空纹理。
    std::vector<unsigned char> blank(static_cast<size_t>(width) * height * 4, 0);
    if (!_texture->initWithData(blank.data(), static_cast<ssize_t>(blank.size()),
                                Texture2D::PixelFormat::RGBA8888, width, height,
                                Size(static_cast<float>(width), static_cast<float>(height))))
    {
        CC_SAFE_DELETE(_texture);
        return;
    }
    _texture->autorelease();

    // NPOT 纹理不能 REPEAT / mipmap。
    Texture2D::TexParams params = { GL_LINEAR, GL_LINEAR, GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE };
    _texture->setTexParameters(params);

    _sprite = Sprite::createWithTexture(_texture);
    if (!_sprite)
    {
        _texture = nullptr;
        return;
    }
    _sprite->setAnchorPoint(Vec2::ZERO);
    _sprite->setScale(_renderScale);
    // 节点原点落在视频中心：setPosition(display.cx, display.cy) 即画面居中
    _sprite->setPosition(Vec2(-static_cast<float>(_videoWidth) * 0.5f,
                             -static_cast<float>(_videoHeight) * 0.5f));
    addChild(_sprite);

    _textureWidth = width;
    _textureHeight = height;
    setContentSize(Size(static_cast<float>(_videoWidth), static_cast<float>(_videoHeight)));

    CCLOG("VideoNode: video=%dx%d render=%dx%d, GL_RENDERER=%s",
          _videoWidth, _videoHeight, width, height,
          reinterpret_cast<const char*>(glGetString(GL_RENDERER)));
}

void VideoNode::destroyTexture()
{
    if (_sprite)
    {
        _sprite->removeFromParent();
        _sprite = nullptr;
    }
    _texture = nullptr;   // 由 Sprite 持有，随 Sprite 释放
    _textureWidth = 0;
    _textureHeight = 0;
}

void VideoNode::onFrameUpdate(float)
{
    ++_updateCount;

    if (!_player)
        return;

    std::shared_ptr<video::VideoFrame> frame;
    if (!_player->takeFrame(_player->clock(), frame))
        return;

    if (!_texture || frame->width != _textureWidth || frame->height != _textureHeight)
        createTexture(frame->width, frame->height);

    if (_texture)
    {
        const auto start = std::chrono::steady_clock::now();
        _texture->updateWithData(frame->rgba.data(), 0, 0, frame->width, frame->height);
        const double ms = std::chrono::duration<double, std::milli>(
                              std::chrono::steady_clock::now() - start).count();
        _uploadMs = _uploadMs * 0.9 + ms * 0.1;   // 指数平均
    }
}

void VideoNode::play()
{
    if (_player)
        _player->play();
}

void VideoNode::pause()
{
    if (_player)
        _player->pause();
}

void VideoNode::resume()
{
    if (_player)
        _player->resume();
}

void VideoNode::stop()
{
    if (_player)
        _player->stop();
}

void VideoNode::seek(float seconds)
{
    if (_player)
        _player->seek(static_cast<double>(seconds));
}

void VideoNode::setLoop(bool loop)
{
    if (_player)
        _player->setLoop(loop);
}

bool VideoNode::isPlaying() const
{
    return _player && _player->isPlaying();
}

float VideoNode::getDuration() const
{
    return _player ? static_cast<float>(_player->duration()) : 0.0f;
}

float VideoNode::getCurrentTime()
{
    return _player ? static_cast<float>(_player->clock()) : 0.0f;
}

unsigned int VideoNode::getDecodedFrames() const
{
    return _player ? static_cast<unsigned int>(_player->decodedFrames()) : 0;
}

unsigned int VideoNode::getRenderedFrames() const
{
    return _player ? static_cast<unsigned int>(_player->renderedFrames()) : 0;
}

unsigned int VideoNode::getSendErrors() const
{
    return _player ? static_cast<unsigned int>(_player->sendErrors()) : 0;
}

unsigned int VideoNode::getUpdateCount() const
{
    return _updateCount;
}

float VideoNode::getUploadMs() const
{
    return static_cast<float>(_uploadMs);
}

unsigned int VideoNode::getPushedFrames() const
{
    return _player ? static_cast<unsigned int>(_player->pushedFrames()) : 0;
}

unsigned int VideoNode::getDroppedFrames() const
{
    return _player ? static_cast<unsigned int>(_player->droppedFrames()) : 0;
}

unsigned int VideoNode::getEmptyPolls() const
{
    return _player ? static_cast<unsigned int>(_player->emptyPolls()) : 0;
}

unsigned int VideoNode::getAudioDrops() const
{
    return _player ? static_cast<unsigned int>(_player->audioDroppedSamples()) : 0;
}

unsigned int VideoNode::getAudioWriteFailures() const
{
    return _player ? static_cast<unsigned int>(_player->audioWriteFailures()) : 0;
}

unsigned int VideoNode::getAudioUnderruns() const
{
    return _player ? static_cast<unsigned int>(_player->audioUnderruns()) : 0;
}

float VideoNode::getVideoWidth() const
{
    return _player ? static_cast<float>(_player->videoWidth()) : 0.0f;
}

float VideoNode::getVideoHeight() const
{
    return _player ? static_cast<float>(_player->videoHeight()) : 0.0f;
}

void VideoNode::setVolume(float volume)
{
    if (_player)
        _player->setVolume(volume);
}

void VideoNode::setEventCallback(const std::function<void(int)>& callback)
{
    _eventCallback = callback;
}

void VideoNode::onEnter()
{
    Node::onEnter();

    // 直接用 Scheduler 注册回调，不依赖 Node::update 的暂停/恢复语义
    if (!_scheduled)
    {
        _scheduled = true;
        Director::getInstance()->getScheduler()->schedule(
            [this](float dt) { this->onFrameUpdate(dt); },
            this, 0.0f, false, "VideoNodeUpdate");
    }

    if (_wasPlaying && _player)
        _player->resume();
}

void VideoNode::onExit()
{
    if (_scheduled)
    {
        Director::getInstance()->getScheduler()->unschedule("VideoNodeUpdate", this);
        _scheduled = false;
    }

    if (_player)
    {
        _wasPlaying = _player->isPlaying();
        _player->pause();
    }
    Node::onExit();
}
