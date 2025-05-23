//Burn and spread fire

#include "Hitters.as";
#include "PoisonCommon.as";

Random _r();

void onInit(CBlob@ this)
{
	if (!this.exists(poison_duration))
		this.set_s16(poison_duration , 130);
	if (!this.exists(poison_hitter))
		this.set_u8(poison_hitter, Hitters::poison);

	if (!this.exists(poison_timer))
		this.set_s16(poison_timer , 0);

	this.getCurrentScript().tickFrequency = poison_wait_ticks;
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (isPoisoningHitter(customData))					 	   // no poison on blocked poison arrow, except spray
	{
		server_setPoisonOn(this);
		if (hitterBlob.getDamageOwnerPlayer() !is null){
			this.set_netid("poison starter player", hitterBlob.getDamageOwnerPlayer().getNetworkID());
		}
	}

	return damage;
}

void onTick(CBlob@ this)
{
	Vec2f pos = this.getPosition();

	s16 poison_time = this.get_s16(poison_timer);

	//check if we're extinguished
	if (poison_time == 0)
	{
		server_setPoisonOff(this);
		this.set_netid("poison starter blob", 0);
	}

	//burnination
	else if (poison_time > 0 && !this.hasTag("dead"))
	{
		s16 poison_count = this.get_s16(poison_counter);
		poison_count++;

		//burninating the actor
		if ((poison_count % 7) == 0)
		{
			uint16 netid = this.get_netid("poison starter player");
			CBlob@ blob = null;
			CPlayer@ player = null;
			if (netid != 0)
				@player = getPlayerByNetworkId(this.get_netid("poison starter player"));

			if (player !is null)
				@blob = player.getBlob();

			if (blob is null)
				@blob = this;

			blob.server_Hit(this, pos, Vec2f(0, 0), 0.25, this.get_u8(poison_hitter), true);
		}

		//burninating the burning time
		poison_time--;

		//making sure to set values correctly
		this.set_s16(poison_timer, poison_time);
		this.set_s16(poison_counter, poison_count);
	}

	// (flax roof cottages!)
}
