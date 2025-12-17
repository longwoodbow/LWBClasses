#define SERVER_ONLY

#include "CratePickupCommon.as"

void onInit(CBlob@ this)
{
	this.getCurrentScript().removeIfTag = "dead";
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (blob is null || blob.getShape().vellen > 1.0f)
	{
		return;
	}

	string blobName = blob.getName();

	if (blobName == "mat_boomerangs")
	{
		u32 boomerangs_count = this.getBlobCount("mat_boomerangs");
		u32 blob_quantity = blob.getQuantity();
		if (boomerangs_count + blob_quantity <= 60)
		{
			this.server_PutInInventory(blob);
		}
		else if (boomerangs_count < 60) //merge into current boomerang stacks
		{
			this.getSprite().PlaySound("/PutInInventory.ogg");

			u32 pickup_amount = Maths::Min(blob_quantity, 60 - boomerangs_count);
			if (blob_quantity - pickup_amount > 0)
				blob.server_SetQuantity(blob_quantity - pickup_amount);
			else
				blob.server_Die();

			CInventory@ inv = this.getInventory();
			for (int i = 0; i < inv.getItemsCount() && pickup_amount > 0; i++)
			{
				CBlob@ boomerangs = inv.getItem(i);
				if (boomerangs !is null && boomerangs.getName() == blobName)
				{
					u32 boomerang_amount = boomerangs.getQuantity();
					u32 boomerang_maximum = boomerangs.getMaxQuantity();
					if (boomerang_amount + pickup_amount < boomerang_maximum)
					{
						boomerangs.server_SetQuantity(boomerang_amount + pickup_amount);
					}
					else
					{
						pickup_amount -= boomerang_maximum - boomerang_amount;
						boomerangs.server_SetQuantity(boomerang_maximum);
					}
				}
			}
		}
	}
	if (blobName == "mat_chakrams")
	{
		if (this.server_PutInInventory(blob))
		{
			return;
		}
	}

	CBlob@ carryblob = this.getCarriedBlob();
	if (carryblob !is null && carryblob.getName() == "crate")
	{
		if (crateTake(carryblob, blob))
		{
			return;
		}
	}
}
