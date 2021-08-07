AddCSLuaFile()

SWEP.PrintName 				= "AR3 CIMR"
SWEP.Author 				= "TankNut"

SWEP.RenderGroup 			= RENDERGROUP_OPAQUE

SWEP.Spawnable 				= true
SWEP.Category 				= "Combine Arms"

SWEP.Slot 					= 3
SWEP.SlotPos 				= 5

SWEP.DrawWeaponInfoBox 		= false
SWEP.DrawCrosshair 			= true

SWEP.ViewModel 				= Model("models/tanknut/weapons/c_ar3_sniper.mdl")
SWEP.WorldModel 			= Model("models/tanknut/weapons/w_ar3_sniper.mdl")

SWEP.UseHands 				= true

SWEP.Primary.ClipSize 		= 10
SWEP.Primary.DefaultClip 	= 30
SWEP.Primary.Ammo 			= "AR2"
SWEP.Primary.Automatic 		= true

SWEP.Secondary.ClipSize 	= -1
SWEP.Secondary.DefaultClip 	= -1
SWEP.Secondary.Ammo 		= ""
SWEP.Secondary.Automatic 	= false

SWEP.HoldType 				= "smg"

SWEP.Damage 				= 40
SWEP.FireRate 				= 60 / 120

-- MOA = 1" per 100 yards
SWEP.Spread 				= (1 / 60) * 2 -- 2 MOA

SWEP.Zoom 					= 3

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)

	if CLIENT then
		hook.Add("PlayerBindPress", self, function(_, ply, bind, pressed)
			if bind == "+zoom" and self == ply:GetActiveWeapon() then
				return true
			end
		end)
	end
end

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "InReload")
	self:NetworkVar("Bool", 1, "InZoom")
end

function SWEP:Deploy()
	self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
	if self:GetInReload() or not self:CanPrimaryAttack() then
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
		TracerName = "AR2Tracer",
		Dir = ply:GetAimVector(),
		Spread = Vector(spread, spread, spread),
		Src = ply:GetShootPos(),
		Callback = function(attacker, tr, dmg)
			local effectdata = EffectData()

			effectdata:SetOrigin(tr.HitPos + tr.HitNormal)
			effectdata:SetNormal(tr.HitNormal)

			util.Effect("AR2Impact", effectdata)
		end
	})

	self:EmitSound("Weapon_AR2.Single")

	if ply:IsPlayer() then
		local kick = Angle(-0.3, math.Rand(-0.2, 0.2), 0)

		ply:SetEyeAngles(ply:EyeAngles() + kick)
		ply:ViewPunch(kick)
	end

	self:SetNextPrimaryFire(CurTime() + self.FireRate)
end

function SWEP:SecondaryAttack()
	self:ToggleZoom()
end

function SWEP:ToggleZoom()
	local ply = self:GetOwner()

	if self:GetInZoom() then
		ply:SetFOV(0, 0.2)

		self:SetInZoom(false)
	else
		ply:SetFOV(ply:GetInfoNum("fov_desired", 75) / self.Zoom, 0.2)

		self:SetInZoom(true)
	end
end

function SWEP:Reload()
	if self:GetInReload() or self:Clip1() == self.Primary.ClipSize then
		return
	end

	self:EmitSound("NPC_Sniper.Reload")

	local ply = self:GetOwner()

	if ply:IsPlayer() then
		local ammo = ply:GetAmmoCount(self.Primary.Ammo)

		if ammo <= 0 then
			return
		end

		self:SetInReload(true)
	end

	ply:SetAnimation(PLAYER_RELOAD)
	self:SendWeaponAnim(ACT_VM_RELOAD)

	self:SetNextPrimaryFire(CurTime() + self:SequenceDuration())
end

function SWEP:Think()
	local ply = self:GetOwner()

	if self:GetInReload() and CurTime() > self:GetNextPrimaryFire() then
		self:SetInReload(false)

		local amt = math.min(ply:GetAmmoCount(self.Primary.Ammo), self.Primary.ClipSize)

		self:SetClip1(amt)

		ply:RemoveAmmo(amt, self.Primary.Ammo)
	end
end

if CLIENT then
	local fov = GetConVar("fov_desired")
	local ratio = GetConVar("zoom_sensitivity_ratio")

	function SWEP:AdjustMouseSensitivity()
		return (LocalPlayer():GetFOV() / fov:GetFloat()) * ratio:GetFloat()
	end

	function SWEP:PreDrawViewModel(vm, wep, ply)
		self.ViewModelFOV = 70 + (fov:GetFloat() - ply:GetFOV()) * 0.6
	end

	function SWEP:CalcViewModelView(vm, oldPos, oldAng, pos, ang)
		return LocalToWorld(Vector(-4, 0, -1.5), Angle(), pos, ang)
	end
end

if SERVER then
	function SWEP:GetCapabilities()
		return bit.bor(CAP_WEAPON_RANGE_ATTACK1, CAP_INNATE_RANGE_ATTACK1)
	end

	local spread = {
		[WEAPON_PROFICIENCY_POOR] = 7,
		[WEAPON_PROFICIENCY_AVERAGE] = 4,
		[WEAPON_PROFICIENCY_GOOD] = 2,
		[WEAPON_PROFICIENCY_VERY_GOOD] = 5 / 3, -- 1.666...
		[WEAPON_PROFICIENCY_PERFECT] = 1
	}

	function SWEP:GetNPCBulletSpread(prof)
		return spread[prof]
	end

	function SWEP:GetNPCBurstSettings()
		return 1, 1, self.FireRate
	end

	function SWEP:GetNPCRestTimes()
		return self.FireRate * 2, self.FireRate * 3
	end
end
