//Handcannon Include

namespace HandcannonParams
{
	enum Aim
	{
		not_aiming = 0,
		igniting,
		ignited,
		firing,
		no_balls,
		digging
	}
	const ::s32 ready_time = 11;
	
	const ::s32 ignite_period = 60;
	const ::s32 shoot_period = 30;

	const ::f32 shoot_max_vel = 17.59f;
}

//TODO: move vars into handcannon params namespace
const f32 handcannon_grapple_length = 72.0f;
const f32 handcannon_grapple_slack = 16.0f;
const f32 handcannon_grapple_throw_speed = 20.0f;

const f32 handcannon_grapple_force = 2.0f;
const f32 handcannon_grapple_accel_limit = 1.5f;
const f32 handcannon_grapple_stiffness = 0.1f;

shared class HandcannonInfo
{
	s8 charge_time;
	u8 charge_state;
	bool has_ball;
	bool has_barricade;
	u8 dig_delay;
	u8 buildmode;

	bool grappling;
	u16 grapple_id;
	f32 grapple_ratio;
	f32 cache_angle;
	Vec2f grapple_pos;
	Vec2f grapple_vel;

	HandcannonInfo()
	{
		charge_time = 0;
		charge_state = 0;
		has_ball = false;
		has_barricade = false;
		buildmode = HandcannonBuilding::nothing;
		grappling = false;
	}
};

const string grapple_sync_cmd = "grapple sync";

void SyncGrapple(CBlob@ this)
{
	HandcannonInfo@ handcannon;
	if (!this.get("handcannonInfo", @handcannon)) { return; }

	if (isClient()) return;

	CBitStream bt;
	bt.write_bool(handcannon.grappling);

	if (handcannon.grappling)
	{
		bt.write_u16(handcannon.grapple_id);
		bt.write_u8(u8(handcannon.grapple_ratio * 250));
		bt.write_Vec2f(handcannon.grapple_pos);
		bt.write_Vec2f(handcannon.grapple_vel);
	}

	this.SendCommand(this.getCommandID(grapple_sync_cmd), bt);
}

//TODO: saferead
void HandleGrapple(CBlob@ this, CBitStream@ bt, bool apply)
{
	HandcannonInfo@ handcannon;
	if (!this.get("handcannonInfo", @handcannon)) { return; }

	bool grappling;
	u16 grapple_id;
	f32 grapple_ratio;
	Vec2f grapple_pos;
	Vec2f grapple_vel;

	grappling = bt.read_bool();

	if (grappling)
	{
		grapple_id = bt.read_u16();
		u8 temp = bt.read_u8();
		grapple_ratio = temp / 250.0f;
		grapple_pos = bt.read_Vec2f();
		grapple_vel = bt.read_Vec2f();
	}

	if (apply)
	{
		handcannon.grappling = grappling;
		if (handcannon.grappling)
		{
			handcannon.grapple_id = grapple_id;
			handcannon.grapple_ratio = grapple_ratio;
			handcannon.grapple_pos = grapple_pos;
			handcannon.grapple_vel = grapple_vel;
		}
	}
}

namespace HandcannonBuilding
{
	enum Building
	{
		nothing,
		barricade,
		count
	}
}

bool hasBalls(CBlob@ this)
{
	return this.getBlobCount("mat_handcannonballs") > 0;
}

bool hasBarricades(CBlob@ this)
{
	return this.getBlobCount("mat_barricades") > 0;
}

bool isBuildTime(CBlob@ this)
{
	return getBuildMode(this) > HandcannonBuilding::nothing;
}

u8 getBuildMode(CBlob@ this)
{	
	HandcannonInfo@ handcannon;
	if (!this.get("handcannonInfo", @handcannon))
	{
		return 0;
	}
	return handcannon.buildmode;
}