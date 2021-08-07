AddCSLuaFile()

SWEP.PrintName 				= "Portable Autogun"
SWEP.Author 				= "TankNut"

SWEP.RenderGroup 			= RENDERGROUP_OPAQUE

SWEP.Spawnable 				= true
SWEP.Category 				= "Combine Arms"

SWEP.Slot 					= 4
SWEP.SlotPos 				= 5

SWEP.DrawWeaponInfoBox 		= false
SWEP.DrawCrosshair 			= false

SWEP.ViewModel 				= Model("models/weapons/v_models/v_cweaponry_rpg.mdl")
SWEP.WorldModel 			= Model("models/weapons/w_models/w_cweaponry_rl.mdl")

SWEP.UseHands 				= false

SWEP.Primary.ClipSize 		= -1
SWEP.Primary.DefaultClip 	= -1
SWEP.Primary.Ammo 			= ""
SWEP.Primary.Automatic 		= false

SWEP.Secondary.ClipSize 	= -1
SWEP.Secondary.DefaultClip 	= -1
SWEP.Secondary.Ammo 		= ""
SWEP.Secondary.Automatic 	= false

SWEP.HoldType 				= "rpg"
SWEP.AltHoldType 			= "physgun"

SWEP.Damage 				= 60
SWEP.FireRate 				= 2

SWEP.Spread 				= (1 / 60) * 16 -- 16 MOA

SWEP.Zoom 					= 2

function SWEP:Initialize()
	self:SetHoldType(self.AltHoldType)

	if CLIENT then
		hook.Add("PostDrawTranslucentRenderables", self, function()
			self:PostDrawTranslucentRenderables()
		end)

		hook.Add("PlayerBindPress", self, function(_, ply, bind, pressed)
			if bind == "+zoom" and self == ply:GetActiveWeapon() then
				return true
			end
		end)
	end
end

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "InZoom")
end

function SWEP:Deploy()
	self:SetInZoom(false)
	self:SetHoldType(self.AltHoldType)

	self:SendWeaponAnim(ACT_VM_IDLE_TO_LOWERED)
end

function SWEP:Holster()
	self:StopSlow()

	return true
end

function SWEP:OwnerChanged()
	self:StopSlow()
end

function SWEP:CanPrimaryAttack()
	return self:GetInZoom()
end

function SWEP:PrimaryAttack()
	if not self:CanPrimaryAttack() then
		return
	end

	local ply = self:GetOwner()

	ply:SetAnimation(PLAYER_ATTACK1)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

	self:TakePrimaryAmmo(1)

	local spread = math.rad(self.Spread * 0.5)

	self:FireBullets({
		Attacker = ply,
		Damage = self.Damage,
		TracerName = "",
		Dir = ply:GetAimVector(),
		Spread = Vector(spread, spread, spread),
		Src = ply:GetShootPos(),
		HullSize = 4,
		Callback = function(attacker, tr, dmg)
			dmg:SetDamageType(DMG_AIRBOAT + DMG_BURN + DMG_BLAST)

			if game.SinglePlayer() then
				self:CallOnClient("DoBeamEffect", tostring(tr.HitPos))
			else
				self:DoBeamEffect(tostring(tr.HitPos))
			end
		end
	})

	self:EmitSound("NPC_Combine_Cannon.FireBullet")

	if ply:IsPlayer() then
		local kick = Angle(-0.5, math.Rand(-0.4, 0.4), 0)

		ply:SetEyeAngles(ply:EyeAngles() + kick)
		ply:ViewPunch(kick)
	end

	self:SetNextPrimaryFire(CurTime() + self.FireRate)
end

function SWEP:DoBeamEffect(vec)
	util.ParticleTracerEx("Weapon_Combine_Ion_Cannon", self:GetOwner():GetShootPos(), Vector(vec), true, self:EntIndex(), 1)
end

function SWEP:SecondaryAttack()
	self:ToggleZoom()
end

function SWEP:StartSlow()
	hook.Add("Move", self, function(ent, ply, mv)
		if ply == ent:GetOwner() then
			local speed = ply:Crouching() and ply:GetWalkSpeed() * ply:GetCrouchedWalkSpeed() or ply:GetSlowWalkSpeed()

			mv:SetMaxSpeed(speed)
			mv:SetMaxClientSpeed(speed)
		end
	end)
end

function SWEP:StopSlow()
	hook.Remove("Move", self)
end

function SWEP:ToggleZoom()
	local ply = self:GetOwner()

	if self:GetInZoom() then
		ply:SetFOV(0, 0.2)

		self:SetInZoom(false)
		self:SetHoldType(self.AltHoldType)
		self:SendWeaponAnim(ACT_VM_IDLE_TO_LOWERED)

		self:SetNextSecondaryFire(CurTime() + ply:GetViewModel():SequenceDuration())

		self:StopSlow()
	else
		self:SendWeaponAnim(ACT_VM_LOWERED_TO_IDLE)

		local time = ply:GetViewModel():SequenceDuration()

		ply:SetFOV(ply:GetInfoNum("fov_desired", 75) / self.Zoom, time)

		self:SetInZoom(true)
		self:SetHoldType(self.HoldType)
		self:SetNextPrimaryFire(CurTime() + time)
		self:SetNextSecondaryFire(CurTime() + time)

		self:StartSlow()
	end


end

function SWEP:TranslateFOV(fov)
	return fov
end

function SWEP:GetAimDir()
	local ply = self:GetOwner()

	return ply:GetAimVector():Angle() + ply:GetViewPunchAngles()
end

function SWEP:GetAimTrace()
	local ply = self:GetOwner()

	return util.TraceLine({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + (self:GetAimDir():Forward() * 8192),
		filter = {ply, self},
		mask = MASK_SHOT
	})
end

if CLIENT then
	local fov = GetConVar("fov_desired")
	local ratio = GetConVar("zoom_sensitivity_ratio")

	local beam = Material("effects/blueblacklargebeam")

	function SWEP:AdjustMouseSensitivity()
		return (LocalPlayer():GetFOV() / fov:GetFloat()) * ratio:GetFloat()
	end

	function SWEP:PreDrawViewModel(vm, wep, ply)
		self.ViewModelFOV = 70 + (fov:GetFloat() - ply:GetFOV()) * 0.6

		if self:ShouldDrawBeam() then
			cam.Start3D(nil, nil, ply:GetFOV())
				cam.IgnoreZ(true)

				local pos = vm:GetAttachment(1).Pos
				local tr = self:GetAimTrace()

				render.SetMaterial(beam)
				render.DrawBeam(pos, tr.HitPos, 5, 0, tr.Fraction * 10, color_white)
			cam.End3D()
		end

		cam.IgnoreZ(true)
	end

	function SWEP:CalcViewModelView(vm, oldPos, oldAng, pos, ang)
		return LocalToWorld(Vector(-4, 0, -1.5), Angle(), pos, ang)
	end

	function SWEP:ShouldDrawBeam()
		return self:GetInZoom() and self:GetNextPrimaryFire() <= CurTime()
	end

	function SWEP:PostDrawTranslucentRenderables()
		local ply = self:GetOwner()

		if not IsValid(ply) or ply:GetActiveWeapon() != self then
			return
		end

		if ply == LocalPlayer() and LocalPlayer():GetViewEntity() == LocalPlayer() and not hook.Run("ShouldDrawLocalPlayer", ply) then
			return
		end

		if ply:InVehicle() then return end
		if ply:GetNoDraw() then return end

		if self:ShouldDrawBeam() then
			local pos = self:GetAttachment(1).Pos
			local tr = self:GetAimTrace()

			render.SetMaterial(beam)
			render.DrawBeam(pos, tr.HitPos, 5, 0, tr.Fraction * 10, color_white)
		end
	end

	function SWEP:DrawWorldModel()
		local ply = self:GetOwner()
		local pos, ang = ply:GetBonePosition(ply:LookupBone("ValveBiped.Bip01_R_Hand"))

		pos, ang = LocalToWorld(Vector(16, -1, -3), Angle(-10, 180, 180), pos, ang)

		self:SetRenderOrigin(pos)
		self:SetRenderAngles(ang)
		self:DrawModel()
	end
end
