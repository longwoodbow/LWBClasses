#include "VehicleCommon.as"
#include "GenericButtonCommon.as"

// Cannon logic

const u8 cooldown_time = 100;

//naming here is kinda counter intuitive, but 0 == up, 90 == sideways
const f32 high_angle = 10.0f;
const f32 low_angle = 80.0f;

class CannonInfo : VehicleInfo
{
	bool canFire(CBlob@ this, AttachmentPoint@ ap)
	{
		if (ap.isKeyPressed(key_action2))
		{
			//cancel
			charge = 0;
			cooldown_time = Maths::Max(cooldown_time, 15);
			return false;
		}

		AmmoInfo@ ammo = getCurrentAmmo();
		const bool isActionPressed = ap.isKeyPressed(key_action1);
		if ((charge > 0 || isActionPressed) && ammo.loaded_ammo > 0)
		{
			if (charge < ammo.max_charge_time && isActionPressed)
			{
				charge++;

				const u8 t = Maths::Round(f32(ammo.max_charge_time) * 0.66f);
				if ((charge < t && charge % 10 == 0) || (charge >= t && charge % 5 == 0))
					this.getSprite().PlaySound("/LoadingTick");

				return false;
			}
			return true;
		}
		return false;
	}
	
	void onFire(CBlob@ this, CBlob@ bullet, const u16 &in fired_charge)
	{
		AmmoInfo@ ammo = getCurrentAmmo();
		if (bullet !is null)
		{
			const f32 temp_charge = 5.0f + 20.0f * (f32(fired_charge) / f32(ammo.max_charge_time));
			const f32 angle = wep_angle + this.getAngleDegrees();
			Vec2f vel = Vec2f(0.0f, -temp_charge).RotateBy(angle);
			bullet.setVelocity(vel);
			bullet.setPosition(bullet.getPosition() + vel);
		}

		last_charge = fired_charge;
		charge = 0;
		cooldown_time = ammo.fire_delay;
	}
}

void onInit(CBlob@ this)
{
	Vec2f wheelPos = Vec2f(8.0f, 9.0f);
	this.set_Vec2f("wheel pos", wheelPos);

	Vehicle_Setup(this,
	              50.0f, // move speed
	              0.31f,  // turn speed
	              Vec2f(0.0f, 0.0f), // jump out velocity
	              false,  // inventory access
	              CannonInfo()
	             );
	VehicleInfo@ v;
	if (!this.get("VehicleInfo", @v)) return;

	Vehicle_AddAmmo(this, v,
	                    cooldown_time, // fire delay (ticks) from 25
	                    1, // fire bullets amount
	                    1, // fire cost
	                    "mat_cannonballs", // bullet ammo config name
	                    "Cannon Balls", // name for ammo selection
	                    "cannonball", // bullet config name
	                    "KegExplosion", // fire sound
	                    "Bomb", // empty fire sound
	                    Vec2f(8, 8), //fire position offset
	                    100 // charge time
	                   );

	Vehicle_SetupGroundSound(this, v, "WoodenWheelsRolling",  // movement sound
	                         1.0f, // movement sound volume modifier   0.0f = no manipulation
	                         1.0f // movement sound pitch modifier     0.0f = no manipulation
	                        );
	Vehicle_addWheel(this, v, "IronWheel.png", 16, 16, 0, wheelPos);

	v.wep_angle = low_angle;

	this.getShape().SetRotationsAllowed(false);

	string[] autograb_blobs = {"mat_cannonballs"};
	this.set("autograb blobs", autograb_blobs);

	this.set_bool("facing", true);

	// auto-load on creation
	if (isServer())
	{
		CBlob@ ammo = server_CreateBlob("mat_cannonballs");
		if (ammo !is null && !this.server_PutInInventory(ammo))
		{
			ammo.server_Die();
		}
	}

	CSprite@ sprite = this.getSprite();
	sprite.SetZ(-25.0f);
	CSpriteLayer@ arm = sprite.addSpriteLayer("arm", sprite.getConsts().filename, 16, 32);
	if (arm !is null)
	{
		Animation@ anim = arm.addAnimation("default", 0, false);
		anim.AddFrame(2);
		arm.RotateBy(low_angle, Vec2f(0.0f, 8.0f));
		arm.SetOffset(Vec2f(8.0f, 0.0f));
		arm.SetRelativeZ(0.08f);
	}

	//UpdateFrame(this); //make damaged sprites?
}

f32 getAimAngle(CBlob@ this, VehicleInfo@ v)
{
	f32 angle = 180.0f; //we'll know if this goes wrong :)
	bool not_found = true;
	const bool facing_left = this.isFacingLeft();
	AttachmentPoint@ gunner = this.getAttachments().getAttachmentPointByName("GUNNER");
	if (gunner !is null && gunner.getOccupied() !is null)
	{
		Vec2f aim_vec = gunner.getPosition() - gunner.getAimPos();

		if ((!facing_left && aim_vec.x < 0) ||
		        (facing_left && aim_vec.x > 0))
		{
			if (aim_vec.x > 0) { aim_vec.x = -aim_vec.x; }
			aim_vec.RotateBy((facing_left ? 1 : -1) * this.getAngleDegrees());
			angle = (-(aim_vec).getAngle() + 270.0f);
			angle = Maths::Max(high_angle , Maths::Min(angle , low_angle));
			not_found = false;
		}
	}

	if (not_found)
	{
		angle = Maths::Abs(v.wep_angle);
		return (facing_left ? -angle : angle);
	}

	if (facing_left) { angle *= -1; }

	return angle;
}

void onTick(CBlob@ this)
{
	if (this.hasAttached() || this.getTickSinceCreated() < 30 || this.get_bool("facing") != this.isFacingLeft())
	{
		VehicleInfo@ v;
		if (!this.get("VehicleInfo", @v)) return;

		Vehicle_StandardControls(this, v);

		if (this.hasAttached() && v.cooldown_time > 0)
		{
			v.cooldown_time--;
		}

		const f32 angle = getAimAngle(this, v);
		v.wep_angle = angle;

		CSprite@ sprite = this.getSprite();
		CSpriteLayer@ arm = sprite.getSpriteLayer("arm");
		if (arm !is null)
		{
			arm.ResetTransform();
			arm.RotateBy(angle, Vec2f(0.0f, 8.0f));
			//arm.animation.frame = v.getCurrentAmmo().loaded_ammo > 0 ? 1 : 0;
		}
	}
	this.set_bool("facing", this.isFacingLeft());
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller)) return;

	if (!Vehicle_AddFlipButton(this, caller) &&
	    caller.getTeamNum() == this.getTeamNum() &&
	    this.getDistanceTo(caller) < this.getRadius() &&
	    !caller.isAttached())
	{
		Vehicle_AddLoadAmmoButton(this, caller);
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return Vehicle_doesCollideWithBlob_ground(this, blob);
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (blob !is null)
	{
		TryToAttachVehicle(this, blob);
	}
}

void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint @attachedPoint)
{
	attachedPoint.offsetZ = 1.0f;
}