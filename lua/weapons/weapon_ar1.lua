AddCSLuaFile()

SWEP.PrintName 				= "AR1"
SWEP.Author 				= "TankNut"

SWEP.RenderGroup 			= RENDERGROUP_OPAQUE

SWEP.Spawnable 				= true
SWEP.Category 				= "Combine Arms"

SWEP.Slot 					= 2
SWEP.SlotPos 				= 5

SWEP.DrawWeaponInfoBox 		= false
SWEP.DrawCrosshair 			= true

SWEP.ViewModelFOV 			= 54

SWEP.ViewModel 				= Model("models/tanknut/weapons/c_ar1.mdl")
SWEP.WorldModel 			= Model("models/tanknut/weapons/w_ar1.mdl")

SWEP.UseHands 				= true

SWEP.Primary.ClipSize 		= 30
SWEP.Primary.DefaultClip 	= 100
SWEP.Primary.Ammo 			= "AR2"
SWEP.Primary.Automatic 		= true

SWEP.Secondary.ClipSize 	= -1
SWEP.Secondary.DefaultClip 	= -1
SWEP.Secondary.Ammo 		= ""
SWEP.Secondary.Automatic 	= false

SWEP.HoldType 				= "smg"

SWEP.Damage 				= 8
SWEP.FireRate 				= 60 / 700

SWEP.Spread 				= 2
SWEP.BurstSpread 			= 1

SWEP.RecoilTime 			= 2
SWEP.RecoilKick 			= 1

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "InReload")
	self:NetworkVar("Bool", 1, "BurstMode")

	self:NetworkVar("Float", 0, "FireStart")

	self:NetworkVar("Int", 0, "BulletsFired")
end

function SWEP:Deploy()
	self:SetHoldType(self.HoldType)
	self:SetFireStart(0)
	self:SetBulletsFired(0)
end

function SWEP:PrimaryAttack()
	if self:GetInReload() or not self:CanPrimaryAttack() then
		return
	end

	local ply = self:GetOwner()

	ply:SetAnimation(PLAYER_ATTACK1)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

	self:TakePrimaryAmmo(1)

	local burst = self:GetBurstMode()

	local baseSpread = burst and self.BurstSpread or self.Spread
	local spread = math.rad(baseSpread * 0.5)

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

	self:EmitSound("NPC_FloorTurret.Shoot")

	if self:GetFireStart() == 0 then
		self:SetFireStart(CurTime())
	end

	self:SetBulletsFired(self:GetBulletsFired() + 1)

	if burst then
		self.Primary.Automatic = self:GetBulletsFired() < 3
	else
		self.Primary.Automatic = true
	end

	if ply:IsPlayer() then
		self:ViewKick(ply, self.RecoilKick, self.RecoilTime)
	end

	self:SetNextPrimaryFire(CurTime() + self.FireRate)
end

function SWEP:ViewKick(ply, kick, time)
	local min = Angle(0.2, 0.2, 0.1)
	local perc = math.min(CurTime() - self:GetFireStart(), time) / time

	ply:ViewPunchReset(10)

	local ang = Angle(
		-(min.p + (kick * perc)),
		-(min.y + (kick * perc) / 3),
		min.r + (kick * perc) / 8
	)

	if math.random(0, 1) == 1 then
		ang.y = -ang.y
	end

	if math.random(0, 1) == 1 then
		ang.z = -ang.z
	end

	ply:ViewPunch(ang * 0.5)
end

function SWEP:SecondaryAttack()
	self:SetBurstMode(not self:GetBurstMode())
	self:EmitSound("Weapon_SMG1.Special1")
end

function SWEP:Reload()
	if self:GetInReload() or self:Clip1() == self.Primary.ClipSize then
		return
	end

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

	if IsValid(ply) and ply:IsPlayer() and not ply:KeyDown(IN_ATTACK) then
		self:SetFireStart(0)
		self:SetBulletsFired(0)
	end
end

if CLIENT then
	function SWEP:CalcViewModelView(vm, oldPos, oldAng, pos, ang)
		return LocalToWorld(Vector(-2, 0, -0.5), Angle(), pos, ang)
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
		return 2, 3, self.FireRate
	end

	function SWEP:GetNPCRestTimes()
		return self.FireRate * 2, self.FireRate * 4
	end
end
