-- 四叉树碰撞检测算法
local QuadTree = {}
QuadTree.__index = QuadTree

-- 矩形结构
local Rect = {}
Rect.__index = Rect

function Rect:new(x, y, width, height)
    local rect = {
        x = x or 0,
        y = y or 0,
        width = width or 0,
        height = height or 0
    }
    setmetatable(rect, Rect)
    return rect
end

function Rect:intersects(other)
    return not (self.x > other.x + other.width or
                self.x + self.width < other.x or
                self.y > other.y + other.height or
                self.y + self.height < other.y)
end

function Rect:containsPoint(x, y)
    return x >= self.x and x <= self.x + self.width and
           y >= self.y and y <= self.y + self.height
end

function Rect:containsRect(other)
    return self.x <= other.x and
           self.y <= other.y and
           self.x + self.width >= other.x + other.width and
           self.y + self.height >= other.y + other.height
end

-- 物体结构（可以存储任意游戏对象）
local GameObject = {}
GameObject.__index = GameObject

function GameObject:new(id, x, y, width, height, data)
    local obj = {
        id = id or 0,
        bounds = Rect:new(x, y, width, height),
        data = data or {}
    }
    setmetatable(obj, GameObject)
    return obj
end

-- 四叉树节点
function QuadTree:new(boundary, capacity)
    local tree = {
        boundary = boundary,          -- 节点边界
        capacity = capacity or 4,     -- 分裂前最大物体数
        objects = {},                 -- 存储的物体
        divided = false,              -- 是否已分裂
        children = {}                 -- 四个子节点
    }
    setmetatable(tree, QuadTree)
    return tree
end

-- 分裂节点为四个象限
function QuadTree:subdivide()
    local x = self.boundary.x
    local y = self.boundary.y
    local w = self.boundary.width / 2
    local h = self.boundary.height / 2
    
    -- 西北象限
    local nw = Rect:new(x, y, w, h)
    self.children[1] = QuadTree:new(nw, self.capacity)
    
    -- 东北象限
    local ne = Rect:new(x + w, y, w, h)
    self.children[2] = QuadTree:new(ne, self.capacity)
    
    -- 西南象限
    local sw = Rect:new(x, y + h, w, h)
    self.children[3] = QuadTree:new(sw, self.capacity)
    
    -- 东南象限
    local se = Rect:new(x + w, y + h, w, h)
    self.children[4] = QuadTree:new(se, self.capacity)
    
    self.divided = true
end

-- 判断物体属于哪个象限（返回象限索引，如果跨越多个则返回nil）
function QuadTree:getQuadrant(object)
    local verticalMidpoint = self.boundary.x + self.boundary.width / 2
    local horizontalMidpoint = self.boundary.y + self.boundary.height / 2
    
    local bounds = object.bounds
    local topHalf = bounds.y < horizontalMidpoint and 
                    bounds.y + bounds.height < horizontalMidpoint
    local bottomHalf = bounds.y > horizontalMidpoint
    
    -- 完全在左半部分
    if bounds.x < verticalMidpoint and bounds.x + bounds.width < verticalMidpoint then
        if topHalf then return 1 end      -- 西北
        if bottomHalf then return 3 end   -- 西南
    end
    
    -- 完全在右半部分
    if bounds.x > verticalMidpoint then
        if topHalf then return 2 end      -- 东北
        if bottomHalf then return 4 end   -- 东南
    end
    
    -- 跨越多个象限
    return nil
end

-- 插入物体
function QuadTree:insert(object)
    -- 检查物体是否在节点边界内
    if not self.boundary:containsRect(object.bounds) then
        return false
    end
    
    -- 如果还有空间且未分裂，直接存储
    if #self.objects < self.capacity and not self.divided then
        table.insert(self.objects, object)
        return true
    end
    
    -- 如果未分裂，先分裂
    if not self.divided then
        self:subdivide()
        
        -- 将现有物体重新分配到子节点
        for i, obj in ipairs(self.objects) do
            local quadrant = self:getQuadrant(obj)
            if quadrant then
                self.children[quadrant]:insert(obj)
            end
        end
        self.objects = {}  -- 清空当前节点的物体
    end
    
    -- 尝试将新物体插入子节点
    local quadrant = self:getQuadrant(object)
    if quadrant then
        return self.children[quadrant]:insert(object)
    else
        -- 物体跨越多个象限，存储在父节点
        table.insert(self.objects, object)
        return true
    end
end

-- 查询区域内的所有物体
function QuadTree:query(range, found)
    found = found or {}
    
    -- 如果范围与节点边界不相交，直接返回
    if not self.boundary:intersects(range) then
        return found
    end
    
    -- 检查当前节点的物体
    for _, object in ipairs(self.objects) do
        if range:intersects(object.bounds) then
            table.insert(found, object)
        end
    end
    
    -- 递归检查子节点
    if self.divided then
        for i = 1, 4 do
            self.children[i]:query(range, found)
        end
    end
    
    return found
end

-- 查找所有碰撞对
function QuadTree:findCollisions()
    local collisions = {}
    local checkedPairs = {}
    
    -- 递归遍历所有节点
    local function traverse(node)
        -- 检查当前节点内的所有物体对
        for i = 1, #node.objects do
            for j = i + 1, #node.objects do
                local obj1 = node.objects[i]
                local obj2 = node.objects[j]
                
                -- 生成唯一标识符避免重复检测
                local pairId = math.min(obj1.id, obj2.id) .. "_" .. math.max(obj1.id, obj2.id)
                
                if not checkedPairs[pairId] then
                    checkedPairs[pairId] = true
                    
                    -- 精确碰撞检测
                    if obj1.bounds:intersects(obj2.bounds) then
                        table.insert(collisions, {
                            obj1 = obj1,
                            obj2 = obj2,
                            collision = true
                        })
                    end
                end
            end
        end
        
        -- 递归遍历子节点
        if node.divided then
            for i = 1, 4 do
                traverse(node.children[i])
            end
        end
    end
    
    traverse(self)
    return collisions
end

-- 清空四叉树
function QuadTree:clear()
    self.objects = {}
    if self.divided then
        for i = 1, 4 do
            self.children[i]:clear()
        end
        self.children = {}
        self.divided = false
    end
end

-- 可视化四叉树（用于调试）
function QuadTree:draw(debugDraw)
    -- 绘制当前节点边界
    if debugDraw then
        debugDraw(self.boundary)
    end
    
    -- 递归绘制子节点
    if self.divided then
        for i = 1, 4 do
            self.children[i]:draw(debugDraw)
        end
    end
end

-- 使用示例
local function exampleUsage()
    -- 创建游戏世界边界
    local worldBounds = Rect:new(0, 0, 1000, 1000)
    
    -- 创建四叉树
    local quadTree = QuadTree:new(worldBounds, 4)
    
    -- 创建一些测试物体
    local objects = {}
    for i = 1, 20 do
        local x = math.random(0, 900)
        local y = math.random(0, 900)
        local width = math.random(20, 50)
        local height = math.random(20, 50)
        
        local obj = GameObject:new(i, x, y, width, height, {
            type = "enemy",
            health = 100
        })
        table.insert(objects, obj)
        
        -- 插入四叉树
        quadTree:insert(obj)
    end
    
    -- 示例1：查询特定区域内的物体
    local queryRange = Rect:new(100, 100, 200, 200)
    local foundObjects = quadTree:query(queryRange)
    
    print("在区域(100,100,200,200)内找到 " .. #foundObjects .. " 个物体")
    
    -- 示例2：检测所有碰撞
    local collisions = quadTree:findCollisions()
    print("检测到 " .. #collisions .. " 个碰撞")
    
    -- 示例3：动态更新（移动物体后重建四叉树）
    quadTree:clear()
    for _, obj in ipairs(objects) do
        -- 模拟物体移动
        obj.bounds.x = obj.bounds.x + math.random(-10, 10)
        obj.bounds.y = obj.bounds.y + math.random(-10, 10)
        quadTree:insert(obj)
    end
    
    -- 重新检测碰撞
    collisions = quadTree:findCollisions()
    print("移动后检测到 " .. #collisions .. " 个碰撞")
    
    return quadTree, objects
end

-- 性能测试函数
local function performanceTest()
    local worldBounds = Rect:new(0, 0, 1000, 1000)
    local quadTree = QuadTree:new(worldBounds, 4)
    
    -- 创建大量物体
    local objectCount = 1000
    local objects = {}
    
    print("性能测试: " .. objectCount .. " 个物体")
    
    -- 测试插入性能
    local startTime = os.clock()
    for i = 1, objectCount do
        local obj = GameObject:new(i, 
            math.random(0, 950), 
            math.random(0, 950), 
            math.random(10, 30), 
            math.random(10, 30)
        )
        table.insert(objects, obj)
        quadTree:insert(obj)
    end
    local insertTime = os.clock() - startTime
    print("插入时间: " .. string.format("%.4f", insertTime) .. " 秒")
    
    -- 测试碰撞检测性能
    startTime = os.clock()
    local collisions = quadTree:findCollisions()
    local collisionTime = os.clock() - startTime
    print("碰撞检测时间: " .. string.format("%.4f", collisionTime) .. " 秒")
    print("检测到碰撞: " .. #collisions .. " 个")
    
    -- 对比暴力检测
    startTime = os.clock()
    local bruteCollisions = {}
    for i = 1, #objects do
        for j = i + 1, #objects do
            if objects[i].bounds:intersects(objects[j].bounds) then
                table.insert(bruteCollisions, {objects[i], objects[j]})
            end
        end
    end
    local bruteTime = os.clock() - startTime
    print("暴力检测时间: " .. string.format("%.4f", bruteTime) .. " 秒")
    print("加速比: " .. string.format("%.2f", bruteTime / collisionTime) .. " 倍")
end

-- 模块导出
return {
    QuadTree = QuadTree,
    Rect = Rect,
    GameObject = GameObject,
    exampleUsage = exampleUsage,
    performanceTest = performanceTest
}