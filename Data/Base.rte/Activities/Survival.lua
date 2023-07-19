function Survival:StartActivity(isNewGame)
	SceneMan.Scene:GetArea("LZ Team 1");
	SceneMan.Scene:GetArea("LZ All");

	self.CPUTechName = self:GetTeamTech(self.CPUTeam);

	self.startMessageTimer = Timer();
	self.enemySpawnTimer = Timer();
	self.winTimer = Timer();

	self.CPUTechName = self:GetTeamTech(self.CPUTeam);

	if isNewGame then
		self:StartNewGame();
	else
		self:ResumeLoadedGame();
	end
end

function Survival:OnSave()
	self:SaveNumber("startMessageTimer.ElapsedSimTimeMS", self.startMessageTimer.ElapsedSimTimeMS);
	self:SaveNumber("enemySpawnTimer.ElapsedSimTimeMS", self.enemySpawnTimer.ElapsedSimTimeMS);
	self:SaveNumber("winTimer.ElapsedSimTimeMS", self.winTimer.ElapsedSimTimeMS);

	self:SaveNumber("timeLimit", self.timeLimit);
	self:SaveString("timeDisplay", self.timeDisplay);
	self:SaveNumber("baseSpawnTime", self.baseSpawnTime);
	self:SaveNumber("randomSpawnTime", self.randomSpawnTime);
	self:SaveNumber("enemySpawnTimeLimit", self.enemySpawnTimeLimit);
end

function Survival:StartNewGame()
	self:SetTeamFunds(1000000, self.CPUTeam);
	self:SetTeamFunds(self:GetStartingGold(), Activity.TEAM_1);

	self.addFogOfWar = self:GetFogOfWarEnabled();

	if self.Difficulty <= GameActivity.CAKEDIFFICULTY then
		self.timeLimit = 125000;
		self.timeDisplay = "two minutes";
		self.baseSpawnTime = 6000;
		self.randomSpawnTime = 8000;
	elseif self.Difficulty <= GameActivity.EASYDIFFICULTY then
		self.timeLimit = 185000;
		self.timeDisplay = "three minutes";
		self.baseSpawnTime = 5500;
		self.randomSpawnTime = 7000;
	elseif self.Difficulty <= GameActivity.MEDIUMDIFFICULTY then
		self.timeLimit = 245000;
		self.timeDisplay = "four minutes";
		self.baseSpawnTime = 5000;
		self.randomSpawnTime = 6000;
	elseif self.Difficulty <= GameActivity.HARDDIFFICULTY then
		self.timeLimit = 305000;
		self.timeDisplay = "five minutes";
		self.baseSpawnTime = 4500;
		self.randomSpawnTime = 5000;
	elseif self.Difficulty <= GameActivity.NUTSDIFFICULTY then
		self.timeLimit = 485000;
		self.timeDisplay = "eight minutes";
		self.baseSpawnTime = 4000;
		self.randomSpawnTime = 4500;
	elseif self.Difficulty <= GameActivity.MAXDIFFICULTY then
		self.timeLimit = 605000;
		self.timeDisplay = "ten minutes";
		self.baseSpawnTime = 3500;
		self.randomSpawnTime = 4000;
	end
	self.enemySpawnTimeLimit = (self.baseSpawnTime + math.random(self.randomSpawnTime)) * rte.SpawnIntervalScale;

	self:SetupHumanPlayerBrains();
end

function Survival:SetupHumanPlayerBrains()
	for player = Activity.PLAYER_1, Activity.MAXPLAYERCOUNT - 1 do
		if self:PlayerActive(player) and self:PlayerHuman(player) then
			if not self:GetPlayerBrain(player) then
				local foundBrain = MovableMan:GetUnassignedBrain(self:GetTeamOfPlayer(player));
				-- If we can't find an unassigned brain in the scene to give each player, then force to go into editing mode to place one
				if not foundBrain then
					self.ActivityState = Activity.EDITING;
					AudioMan:ClearMusicQueue();
					AudioMan:PlayMusic("Base.rte/Music/dBSoundworks/ccambient4.ogg", -1, -1);
				else
					-- Set the found brain to be the selected actor at start
					self:SetPlayerBrain(foundBrain, player);
					self:SwitchToActor(foundBrain, player, self:GetTeamOfPlayer(player));
					self:SetLandingZone(self:GetPlayerBrain(player).Pos, player);
					-- Set the observation target to the brain, so that if/when it dies, the view flies to it in observation mode
					self:SetObservationTarget(self:GetPlayerBrain(player).Pos, player);
				end
			end
		end
	end
end

function Survival:ResumeLoadedGame()
	self.startMessageTimer.ElapsedSimTimeMS = self:LoadNumber("startMessageTimer.ElapsedSimTimeMS");
	self.enemySpawnTimer.ElapsedSimTimeMS = self:LoadNumber("enemySpawnTimer.ElapsedSimTimeMS");
	self.winTimer.ElapsedSimTimeMS = self:LoadNumber("winTimer.ElapsedSimTimeMS");

	self.timeLimit = self:LoadNumber("timeLimit");
	self.timeDisplay = self:LoadString("timeDisplay");
	self.baseSpawnTime = self:LoadNumber("baseSpawnTime");
	self.randomSpawnTime = self:LoadNumber("goldNeeded");
	self.enemySpawnTimeLimit = self:LoadNumber("enemySpawnTimeLimit");
end

function Survival:EndActivity()
	-- Temp fix so music doesn't start playing if ending the Activity when changing resolution through the ingame settings.
	if not self:IsPaused() then
		-- Play sad music if no humans are left
		if self:HumanBrainCount() == 0 then
			AudioMan:ClearMusicQueue();
			AudioMan:PlayMusic("Base.rte/Music/dBSoundworks/udiedfinal.ogg", 2, -1.0);
			AudioMan:QueueSilence(10);
			AudioMan:QueueMusicStream("Base.rte/Music/dBSoundworks/ccambient4.ogg");
		else
			-- But if humans are left, then play happy music!
			AudioMan:ClearMusicQueue();
			AudioMan:PlayMusic("Base.rte/Music/dBSoundworks/uwinfinal.ogg", 2, -1.0);
			AudioMan:QueueSilence(10);
			AudioMan:QueueMusicStream("Base.rte/Music/dBSoundworks/ccambient4.ogg");
		end
	end
end

function Survival:UpdateActivity()
	self:ClearObjectivePoints();

	if self.ActivityState ~= Activity.OVER and self.ActivityState ~= Activity.EDITING then
		for player = Activity.PLAYER_1, Activity.MAXPLAYERCOUNT - 1 do
			if self:PlayerActive(player) and self:PlayerHuman(player) then
				--Display messages.
				if self.startMessageTimer:IsPastSimMS(3000) then
					local secondsLeft = math.floor(self.winTimer:LeftTillSimMS(self.timeLimit) / 1000);
					if (secondsLeft > 1) then
						FrameMan:SetScreenText(secondsLeft .. " seconds left", player, 0, 1000, false);
					else
						FrameMan:SetScreenText("1 second left!", player, 0, 1000, false);
					end
				else
					FrameMan:SetScreenText("Survive for " .. self.timeDisplay .. "!", player, 333, 5000, true);
				end

				-- The current player's team
				local team = self:GetTeamOfPlayer(player);

				-- If player brain is dead then try to find another, maybe he just entered craft
				if not MovableMan:IsActor(self:GetPlayerBrain(player)) then
					local newBrain = MovableMan:GetUnassignedBrain(self:GetTeamOfPlayer(player));
					if newBrain then
						self:SetPlayerBrain(newBrain, player);
						self:SwitchToActor(newBrain, player, self:GetTeamOfPlayer(player));
						self:SetObservationTarget(self:GetPlayerBrain(player).Pos, player);
					end
				end

				-- Check if any player's brain is dead and we could not find another
				if not MovableMan:IsActor(self:GetPlayerBrain(player)) then
					self:SetPlayerBrain(nil, player);
					self:ResetMessageTimer(player);
					FrameMan:ClearScreenText(player);
					FrameMan:SetScreenText("Your brain has been destroyed!", player, 333, -1, false);
					-- Now see if all brains of self player's team are dead, and if so, end the game
					if not MovableMan:GetFirstBrainActor(team) then
						self.WinnerTeam = self:OtherTeam(team);
						ActivityMan:EndActivity();
					end
				else
					self:AddObjectivePoint("Protect!", self:GetPlayerBrain(player).AboveHUDPos, self:GetTeamOfPlayer(player), GameActivity.ARROWDOWN);
				end

				--Check if the player has won.
				if self.winTimer:IsPastSimMS(self.timeLimit) then
					self:ResetMessageTimer(player);
					FrameMan:ClearScreenText(player);
					FrameMan:SetScreenText("You survived!", player, 333, -1, false);

					self.WinnerTeam = Activity.TEAM_1;

					--Kill all enemies.
					for actor in MovableMan.Actors do
						if actor.Team ~= self.WinnerTeam then
							actor.Health = 0;
						end
					end

					ActivityMan:EndActivity();
				end
			end
		end

		if self.addFogOfWar then
			SceneMan:MakeAllUnseen(Vector(20, 20), self:GetTeamOfPlayer(Activity.PLAYER_1));
			self.addFogOfWar = false;
		end

		--Spawn the AI.
		if self.CPUTeam ~= Activity.NOTEAM and self.enemySpawnTimer:LeftTillSimMS(self.enemySpawnTimeLimit) <= 0 and MovableMan:GetTeamMOIDCount(self.CPUTeam) <= rte.AIMOIDMax * 3 / self:GetActiveCPUTeamCount() then
		local ship, actorsInCargo;

			if math.random() < 0.5 then
				-- Set up the ship to deliver this stuff
				ship = RandomACDropShip("Any", self.CPUTechName);
				-- If we can't afford this dropship, then try a rocket instead
				if ship:GetTotalValue(0,3) > self:GetTeamFunds(self.CPUTeam) then
					DeleteEntity(ship);
					ship = RandomACRocket("Any", self.CPUTechName);
				end
				actorsInCargo = ship.MaxPassengers;
			else
				ship = RandomACRocket("Any", self.CPUTechName);
				actorsInCargo = math.min(ship.MaxPassengers, 2);
			end

			ship.Team = self.CPUTeam;

			-- Set the ship up with a cargo of a few armed and equipped actors
			for i = 1, actorsInCargo do
				-- Get any Actor from the CPU's native tech
				local passenger = nil;
				if math.random() >= self:GetCrabToHumanSpawnRatio(ModuleMan:GetModuleID(self.CPUTechName)) then
					passenger = RandomAHuman("Any", self.CPUTechName);
				else
					passenger = RandomACrab("Actors - Mecha", self.CPUTechName);
				end
				-- Equip it with tools and guns if it's a humanoid
				if IsAHuman(passenger) then
					passenger:AddInventoryItem(RandomHDFirearm("Weapons - Primary", self.CPUTechName));
					passenger:AddInventoryItem(RandomHDFirearm("Weapons - Secondary", self.CPUTechName));
					if math.random() < 0.5 then
						passenger:AddInventoryItem(RandomTDExplosive("Bombs - Grenades", self.CPUTechName));
					elseif math.random() < 0.8 then
						passenger:AddInventoryItem(CreateHDFirearm("Medikit", "Base.rte"));
					else
						if math.random() < 0.75 then
							passenger:AddInventoryItem(RandomHDFirearm("Tools - Breaching", self.CPUTechName));
						else
							passenger:AddInventoryItem(RandomTDExplosive("Tools - Breaching", self.CPUTechName));
						end
					end
				end
				-- Set AI mode and team so it knows who and what to fight for!
				passenger.AIMode = Actor.AIMODE_BRAINHUNT;
				passenger.Team = self.CPUTeam;

				-- Check that we can afford to buy and to carry the weight of this passenger
				if ship:GetTotalValue(0,3) + passenger:GetTotalValue(0,3) <= self:GetTeamFunds(self.CPUTeam) and passenger.Mass <= ship.MaxInventoryMass then
					-- Yes we can; so add it to the cargo hold
					ship:AddInventoryItem(passenger);
					passenger = nil;
				else
					-- Nope; just delete the nixed passenger and stop adding new ones
					-- This doesn't need to be explicitly deleted here, teh garbage collection would do it eventually..
					-- but since we're so sure we don't need it, might as well go ahead and do it here right away
					DeleteEntity(passenger);
					passenger = nil;

					if i < 2 then	-- Don't deliver empty craft
						DeleteEntity(ship);
						ship = nil;
					end

					break;
				end
			end

			if ship then
				-- Set the spawn point of the ship from orbit
				if self.playertally == 1 then
					for i = 1, #self.playerlist do
						if self.playerlist[i] == true then
							local sceneChunk = SceneMan.SceneWidth / 3;
							local checkPos = self:GetPlayerBrain(i - 1).Pos.X + (SceneMan.SceneWidth/2) + ( (sceneChunk/2) - (math.random()*sceneChunk) );
							if checkPos > SceneMan.SceneWidth then
								checkPos = checkPos - SceneMan.SceneWidth;
							elseif checkPos < 0 then
								checkPos = SceneMan.SceneWidth + checkPos;
							end
							ship.Pos = Vector(checkPos,-50);
							break;
						end
					end
				else
					if SceneMan.SceneWrapsX then
						ship.Pos = Vector(math.random() * SceneMan.SceneWidth, -50);
					else
						ship.Pos = Vector(RangeRand(100, SceneMan.SceneWidth-100), -50);
					end
				end

				-- Double-check if the computer can afford this ship and cargo, then subtract the total value from the team's funds
				local shipValue = ship:GetTotalValue(0,3);
				if shipValue <= self:GetTeamFunds(self.CPUTeam) then
					-- Subtract the total value of the ship+cargo from the CPU team's funds
					self:ChangeTeamFunds(-shipValue, self.CPUTeam);
					-- Spawn the ship onto the scene
					MovableMan:AddActor(ship);
				else
					-- The ship and its contents is deleted if it can't be afforded
					-- This doesn't need to be explicitly deleted here, teh garbage collection would do it eventually..
					-- but since we're so sure we don't need it, might as well go ahead and do it here right away
					DeleteEntity(ship);
					ship = nil;
				end
			end

			self.enemySpawnTimer:Reset();
			self.enemySpawnTimeLimit = (self.baseSpawnTime + math.random(self.randomSpawnTime) * rte.SpawnIntervalScale);
		end
	else
		self.startMessageTimer:Reset();
		self.winTimer:Reset();
	end

	self:YSortObjectivePoints();
end