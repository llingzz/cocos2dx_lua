-- 确定性有序表类
local OrderedTable = class("OrderedTable")

function OrderedTable:ctor()
    -- 维护键的顺序
    self.keys = {}
    -- 存储实际数据
    self.values = {}
end

-- 添加元素
function OrderedTable:set(key, value)
    if self.values[key] == nil then
        -- 新键，添加到keys末尾
        table.insert(self.keys, key)
    end
    self.values[key] = value
end

-- 获取元素
function OrderedTable:get(key)
    return self.values[key]
end

-- 按顺序遍历
function OrderedTable:pairs()
    local i = 0
    return function()
        i = i + 1
        local key = self.keys[i]
        if key then
            return key, self.values[key]
        end
    end
end

-- 删除元素
function OrderedTable:remove(key)
    if self.values[key] ~= nil then
        self.values[key] = nil
        for i, k in ipairs(self.keys) do
            if k == key then
                table.remove(self.keys, i)
                break
            end
        end
    end
end

-- local ot = OrderedTable:new()
-- -- 乱序添加
-- ot:set("c", "值C")
-- ot:set("a", "值A") 
-- ot:set("b", "值B")
-- ot:set(1, "数字1")
-- ot:set(3, "数字3")
-- ot:set(2, "数字2")
-- print("按添加顺序遍历:")
-- for k, v in ot:pairs() do
--     print(k, v)
-- end
-- -- 删除一个元素
-- ot:remove("a")
-- print("\n删除'a'后:")
-- for k, v in ot:pairs() do
--     print(k, v)
-- end

return OrderedTable