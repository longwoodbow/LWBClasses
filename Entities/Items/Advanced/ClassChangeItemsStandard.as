#include "GenericButtonCommon.as";
#include "StandardRespawnCommand.as"

void onInit(CBlob@ this)
{
  this.AddScript("OffscreenThrottle.as");

  //AddIconToken("$change_class$", "/GUI/InteractionIcons.png", Vec2f(32, 32), 12, 2);

  this.Tag('material');
  this.Tag("pushedByDoor");

  this.addCommandID("change class");

  this.getShape().getVars().waterDragScale = 12.f;
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
  if (!canSeeButtons(this, caller) || caller.getName() == this.get_string("requied class")) return;

  CBitStream params;
  caller.CreateGenericButton("$change_class$", Vec2f_zero, this, this.getCommandID("change class"), ("Use this to become {CLASS}").replace("{CLASS}", this.get_string("description")), params);
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
  // took from StandardRespawnCommand.as
  if (cmd == this.getCommandID("change class") && isServer())
  {
    CPlayer@ callerp = getNet().getActiveCommandPlayer();
    if (callerp is null) return;

    CBlob@ caller = callerp.getBlob();
    if (caller is null) return;

    if (!canChangeClass(this, caller)) return;

    string classconfig = "knight";

    if (this.exists("required class")) // Maybe single class available?
    {
      classconfig = this.get_string("required class");
    }
    else // No classes available?
    {
      return;
    }

    // Caller overlapping?
    //if (!caller.isOverlapping(this)) return; // because of this
    if (!canSeeButtons(this, caller)) return;
 
    // Don't spam the server with class change
    if (caller.getTickSinceCreated() < 10) return;

    CBlob @newBlob = server_CreateBlob(classconfig, caller.getTeamNum(), this.getRespawnPosition());

    if (newBlob !is null)
    {
      // copy health and inventory
      // make sack
      CInventory @inv = caller.getInventory();

      if (inv !is null)
      {
        if (this.hasTag("change class drop inventory"))
        {
          while (inv.getItemsCount() > 0)
          {
            CBlob @item = inv.getItem(0);
            caller.server_PutOutInventory(item);
          }
        }
        else if (this.hasTag("change class store inventory"))
        {
          if (this.getInventory() !is null)
          {
            caller.MoveInventoryTo(this);
          }
          else // find a storage
          {
            PutInvInStorage(caller);
          }
        }
        else
        {
          // keep inventory if possible
          caller.MoveInventoryTo(newBlob);
        }
      }

      // set health to be same ratio
      float healthratio = caller.getHealth() / caller.getInitialHealth();
      newBlob.server_SetHealth(newBlob.getInitialHealth() * healthratio);

      //copy air
      if (caller.exists("air_count"))
      {
        newBlob.set_u8("air_count", caller.get_u8("air_count"));
        newBlob.Sync("air_count", true);
      }

      //copy stun
      if (isKnockable(caller))
      {
        setKnocked(newBlob, getKnockedRemaining(caller));
      }

      // plug the soul
      newBlob.server_SetPlayer(caller.getPlayer());
      newBlob.setPosition(caller.getPosition());

      // no extra immunity after class change
      if (caller.exists("spawn immunity time"))
      {
        newBlob.set_u32("spawn immunity time", caller.get_u32("spawn immunity time"));
        newBlob.Sync("spawn immunity time", true);
      }

      caller.Tag("switch class");
      caller.server_SetPlayer(null);
      caller.server_Die();
      this.server_Die();
    }
  }
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
  if (blob.hasTag('solid')) return true;

  if (blob.getShape().isStatic()) return true;

  return false;
}
