// low moving speed while poisoned
#include "PoisonCommon.as";
#include "RunnerCommon.as";

void onInit(CBlob@ this)
{
	this.getCurrentScript().tickIfTag = poisoning_tag;
	this.getCurrentScript().removeIfTag = "dead";
}

void onTick(CBlob@ this)
{
	if (this.getHealth() > 0.0f)
	{
		if(this.hasTag(poisoning_tag)) // double check
		{
			RunnerMoveVars@ moveVars;
			if (this.get("moveVars", @moveVars))
			{
				moveVars.walkFactor *= 0.5f;
				moveVars.jumpFactor *= 0.5f;
			}
		}
	}
}