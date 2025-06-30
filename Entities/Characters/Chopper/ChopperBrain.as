// Knight brain

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
	//if (sv_test)
	//	return;
	//	 blob.setKeyPressed( key_action2, true );
	//	return;
	// logic for target

	this.getCurrentScript().tickFrequency = 29;
	if (target !is null)
	{
		this.getCurrentScript().tickFrequency = 1;

		u8 strategy = blob.get_u8("strategy");

		f32 distance;
		const bool visibleTarget = isVisible(blob, target, distance);
		if (visibleTarget && distance < 50.0f)
		{
			strategy = Strategy::attacking;
		}

		if (strategy == Strategy::idle)
		{
			strategy = Strategy::chasing;
		}
		else if (strategy == Strategy::chasing)
		{
		}
		else if (strategy == Strategy::attacking)
		{
			if (!visibleTarget || distance > 120.0f)
			{
				strategy = Strategy::chasing;
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

	if (targetDistance > blob.getRadius() + 15.0f)
	{
		if (!isFriendAheadOfMe(blob, target))
		{
			Chase(blob, target);
		}
	}

	JumpOverObstacles(blob);

	// aim always at enemy
	blob.setAimPos(targetPos);

	const u32 gametime = getGameTime();

	bool backOffTime = gametime - blob.get_u32("backoff time") < uint(1 + XORRandom(20));

	{
		// start attack
		if (XORRandom(Maths::Max(3, 30 - (difficulty + 4) * 2)) == 0 && (getGameTime() - blob.get_u32("attack time")) > 10)
		{

			// base on difficulty
			blob.set_u32("attack time", gametime);
		}
	}

	if (backOffTime)   // back off for a bit
	{
		Runaway(blob, target);
	}
	else if (targetDistance < 40.0f && getGameTime() - blob.get_u32("attack time") < (Maths::Min(13, difficulty + 3))) // release and attack when appropriate
	{
		blob.setKeyPressed(key_action2, true);
	}
}

