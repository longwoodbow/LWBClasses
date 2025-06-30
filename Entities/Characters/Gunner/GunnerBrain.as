// Gunner brain

#define SERVER_ONLY

#include "BrainCommon.as"
#include "GunnerCommon.as"

void onInit(CBrain@ this)
{
	InitBrain(this);
}

void onTick(CBrain@ this)
{
	SearchTarget(this, false, true);

	CBlob @blob = this.getBlob();
	CBlob @target = this.getTarget();

	// logic for target

	this.getCurrentScript().tickFrequency = 29;
	if (target !is null)
	{
		this.getCurrentScript().tickFrequency = 1;

		u8 strategy = blob.get_u8("strategy");
		const bool gotbullets = hasBullets(blob);
		if (!gotbullets)
		{
			strategy = Strategy::idle;
		}

		f32 distance;
		const bool visibleTarget = isVisible(blob, target, distance);
		if (visibleTarget)
		{
			const s32 difficulty = blob.get_s32("difficulty");
			if ((!blob.isKeyPressed(key_action1) && getGameTime() % 300 < 240 && distance < 30.0f + 3.0f * difficulty) || !gotbullets)
				strategy = Strategy::retreating;
			else if (gotbullets)
			{
				strategy = Strategy::attacking;
			}
		}

		UpdateBlob(blob, target, strategy);

		// lose target if its killed (with random cooldown)

		if (LoseTarget(this, target))
		{
			strategy = Strategy::idle;
		}

		blob.set_u8("strategy", strategy);
	}
	else
	{
		RandomTurn(blob);
	}

	FloatInWater(blob);
}

void UpdateBlob(CBlob@ blob, CBlob@ target, const u8 strategy)
{
	Vec2f targetPos = target.getPosition();
	Vec2f myPos = blob.getPosition();
	if (strategy == Strategy::chasing)
	{
		DefaultChaseBlob(blob, target);
	}
	else if (strategy == Strategy::retreating)
	{
		DefaultRetreatBlob(blob, target);
	}
	else if (strategy == Strategy::attacking)
	{
		AttackBlob(blob, target);
	}
}


void AttackBlob(CBlob@ blob, CBlob @target)
{
	Vec2f mypos = blob.getPosition();
	Vec2f targetPos = target.getPosition();
	Vec2f targetVector = targetPos - mypos;
	f32 targetDistance = targetVector.Length();
	const s32 difficulty = blob.get_s32("difficulty");

	JumpOverObstacles(blob);

	const u32 gametime = getGameTime();

	// fire

	if (targetDistance > 25.0f)
	{
		u32 fTime = blob.get_u32("fire time");  // first shot
		bool fireTime = gametime < fTime;

		if (!fireTime && (fTime == 0 || XORRandom(130 - 5.0f * difficulty) == 0))		// difficulty
		{
			const f32 vert_dist = Maths::Abs(targetPos.y - mypos.y);
			const u32 shootTime = Maths::Max(GunnerParams::shoot_period + GunnerParams::ready_time, Maths::Min(uint(targetDistance * (0.3f * Maths::Max(130.0f, vert_dist) / 100.0f) + XORRandom(20)), GunnerParams::snipe_period + GunnerParams::ready_time));
			blob.set_u32("fire time", gametime + shootTime);
		}

		if (fireTime)
		{
			blob.setAimPos(targetPos);
			blob.setKeyPressed(key_action1, true);
		}
	}
	else
	{
		blob.setAimPos(targetPos);
	}
}

