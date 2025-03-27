
--COCOS对象池，对象基本类型是Node
local ObjectPool = class("ObjectPool")

function ObjectPool:ctor(name,config)
    self.co = nil
	self.config = config
	self.name = name
	self.preloadcount = 0
	self.despawned = {}
end

function ObjectPool:clean()
	for _,obj in ipairs(self.despawned) do
		obj[1]:release()
		print(string.format("ObjectPool:clean release %s refcount %d",tostring(obj[1]),obj[1]:getReferenceCount()))
	end
	self.despawned = {}
end

function ObjectPool:count()
	return #self.despawned
end

function ObjectPool:despawn(obj)
	table.insert(self.despawned,{obj,0})
end

function ObjectPool:load()
	local obj = self.config.load(self.name)
    --重写removeSelf函数
	obj.removeSelf = function()
        if not obj:getParent() then
            return
        end
		obj:retain()
		obj:removeFromParent(false)
		self:despawn(obj)
		print(string.format("ObjectPool:load removeSelf %s refcount %d",tostring(obj),obj:getReferenceCount()))
	end
	return obj
end

function ObjectPool:spawn()
	local config = self.config
	local n = #self.despawned
	local obj
	if 0 == n then
		obj = self:load(self.name)
	else
		obj = self.despawned[n][1]
		table.remove(self.despawned,n)
        if obj.reload then
            obj:reload()
        end
		Scheduler:performWithDelayGlobal(function()
			obj:release()
		end,0)
	end
	obj:setVisible(true)
	print(string.format("ObjectPool:spawn %s refcount %d",tostring(obj),obj:getReferenceCount()))
	return obj
end

function ObjectPool:preload(preloadcount)
	local config = self.config
	if not preloadcount then
		preloadcount = config.preloadamount
	end
	if preloadcount <= 0 or self.preloading then
		return
	end
	local amount = preloadcount - self:count()
	if amount <= 0 then
		return
	end
	self.preloadcount = amount
	if config.preloadovertime then
		self.preloading = true
		local function yield_resume(co,delay)
			Scheduler:performWithDelayGlobal(function() coroutine.resume(co,nil) end,delay)
			coroutine.yield()
		end
		local function preloadOverTime()
			if config.preloaddelay > 0 then
				yield_resume(self.co,config.preloaddelay)
			end
            while self.preloadcount > 0 do
                local numthisframe = config.preloadoneframe
                if numthisframe > self.preloadcount then
                    numthisframe = self.preloadcount
                end
                for n = 1,numthisframe do
                	local r = self:load()
                	if r then
                		r:retain()
                		table.insert(self.despawned,{r,-1})
						print(string.format("ObjectPool:preload 1 %s refcount %d",tostring(r),r:getReferenceCount()))
                	end
                end
                self.preloadcount = self.preloadcount - numthisframe
				yield_resume(self.co,0)
                if self:count() > preloadcount then
                    break
                end
            end
            self.preloadcount = 0
            self.preloading = false
		end
        self.co = coroutine.create(preloadOverTime)
        coroutine.resume(self.co,nil)
	else
		for i = 1,self.preloadcount do
            local r = self:load()
            if r then
            	r:retain()
                table.insert(self.despawned,{r,-1})
				print(string.format("ObjectPool:preload 2 %s refcount %d",tostring(r),r:getReferenceCount()))
            end
		end
		self.preloadcount = 0
	end
end

function ObjectPool:update(delta)
	for i = #self.despawned,1,-1 do
		local obj = self.despawned[i]
		if obj[2] >= 0 then
			obj[2] = obj[2] + delta
			if obj[2] >= self.config.duration then
				table.remove(self.despawned,i)
                obj[1]:release()
				print(string.format("ObjectPool:update release %s refcount %d",tostring(obj[1]),obj[1]:getReferenceCount()))
			end
		end
	end
end

--管理相同配置的不同对象池
local SpawnPool = class("SpawnPool")

function SpawnPool:ctor(config)
	self.config = config
	self.objectpool = {}
end

function SpawnPool:clean()
	for _,respool in ipairs(self.objectpool) do
		respool:clean()
	end
	self.objectpool = {}
end

function SpawnPool:update(delta)
	if self.config.duration <= 0 then
		return
	end
	for _,respool in ipairs(self.objectpool) do
		respool:update(delta)
	end
end

function SpawnPool:getPreload()
	local n = 0
	for _,respool in ipairs(self.objectpool) do
		n = n + respool.preloadcount
	end
	return n
end

function SpawnPool:onChangeScene()
	if self.config.duration ~= -1 then
		return
	end
	for _,respool in ipairs(self.objectpool) do
		respool:clean()
	end
end

--添加资源，预载入用
function SpawnPool:preload(file,count)
	local respool = self:getObjectPool(file)
	respool:preload(count)
end

function SpawnPool:getObjectPool(name,notautocreate)
	for _,respool in ipairs(self.objectpool) do
		if respool.name == name then
			return respool
		end
	end
	if notautocreate then
		return
	end
	local r = ObjectPool:create(name,self.config)
	table.insert(self.objectpool,r)
	return r
end

function SpawnPool:spawn(name)
	local respool = self:getObjectPool(name)
	return respool:spawn()
end

function SpawnPool:removeUnused(name)
	local respool = self:getObjectPool(name,true)
	if not respool then
		return
	end
	respool:clean()
end

local ManagerResource = class("ManagerResource")

function ManagerResource:ctor()
	self.pools = {}
	cc.Director:getInstance():getScheduler():scheduleScriptFunc(handler(self,self.update),0,false)
end

function ManagerResource:createSpawnPool(name,config)
	if self.pools[name] then
		return
	end
	local respool = SpawnPool:create(config)
	self.pools[name] = respool
	return respool	
end

function ManagerResource:update(delta)
	for _,respool in pairs(self.pools) do
		respool:update(delta)
	end
end

function ManagerResource:onChangeScene()
	for _,respool in pairs(self.pools) do
		respool:onChangeScene()
	end
end

function ManagerResource:getPreload()
	local n = 0
	for _,respool in pairs(self.pools) do
		n = n + respool:getPreload()
	end
	return n
end

return ManagerResource