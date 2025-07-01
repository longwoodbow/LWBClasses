// Crossbowman brain

#define SERVER_ONLY

#include "BrainCommon.as"

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

	this.getCurrentScript().tickFrequency = 1;
	if (target !is null)
	{
		this.getCurrentScript().tickFrequency = 1;

		u8 strategy = blob.get_u8("strategy");
		const bool gotmeats = blob.hasBlob("mat_poisonmeats", 1);
		if (!gotmeats)
		{
			strategy = Strategy::idle;
		}

		f32 distance;
		const bool visibleTarget = isVisible(blob, target, distance);
		if (visibleTarget)
		{
			strategy = Strategy::attacking;
		}

		UpdateBlob(blob, target, strategy);

		// lose target if its killed (with random cooldown)

		if (LoseTarget(this, target))
		{
			if(blob.getTeamNum() == 0)
			goRight(blob);
			else 
			goLeft(blob);
		}

		blob.set_u8("strategy", strategy);
	}
	if (target is null)
	{
		if(blob.getTeamNum() == 0)
			goRight(blob);
		else 
			goLeft(blob);
		
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

	if (targetDistance > 25.0f && blob.hasBlob("mat_poisonmeats", 1))
	{
		bool worthShooting;
		bool hardShot = targetDistance > 30.0f * 8.0f || target.getShape().vellen > 5.0f;
		f32 aimFactor = 0.45f - XORRandom(100) * 0.003f;
		aimFactor += (-0.2f + XORRandom(100) * 0.004f) / float(difficulty > 0 ? difficulty : 1.0f);
		blob.setAimPos(blob.getBrain().getShootAimPosition(targetPos, hardShot, worthShooting, aimFactor));
		if (worthShooting)
		{
			blob.setKeyPressed(key_action2, true);
		}
	}
	else
	{
		Chase(blob, target);
		blob.setAimPos(targetPos);
		blob.setKeyPressed(key_action1, true);
	}
}

