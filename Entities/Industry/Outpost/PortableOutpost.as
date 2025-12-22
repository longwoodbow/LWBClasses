// Outpost
// added heavy weight
#include "StandardRespawnCommand.as";
#include "GenericButtonCommon.as"

void onInit( CBlob@ this )
{
	this.SetLight( true );
    this.SetLightRadius( 16.0f );
    this.SetLightColor( SColor(255, 255, 240, 171 ) );

	this.Tag("respawn");

	InitClasses( this );
	this.Tag("change class store inventory");
	this.Tag("heavy weight");

	this.getShape().SetRotationsAllowed( false );
	this.set_s32("gold building amount", 50);
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller)) return;

	// button for runner
	// create menu for class change
	if (canChangeClass(this, caller) && caller.getTeamNum() == this.getTeamNum())
	{
		caller.CreateGenericButton("$change_class$", Vec2f(0, -8), this, buildSpawnMenu, getTranslatedString("Swap Class"));
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	onRespawnCommand(this, cmd, params);
}

bool canBePickedUp( CBlob@ this, CBlob@ byBlob )
{
	return (byBlob.getTeamNum() == this.getTeamNum());
}

bool isInventoryAccessible( CBlob@ this, CBlob@ forBlob )
{
	return ( forBlob.getTeamNum() == this.getTeamNum() && forBlob.isOverlapping(this) );
}