--[[MULTITHREAD]]--

require("AI/NativeDropShipAI");

function Create(self)
	self.AI = NativeDropShipAI:Create(self);
end

function UpdateAI(self)
	self.AI:Update(self);
end