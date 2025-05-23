// For crate autopickups
// added new items.

bool crateTake(CBlob@ this, CBlob@ blob)
{
    if (this.exists("packed"))
    {
        return false;
    }

    const string blobName = blob.getName();

    if (   blobName == "mat_gold"
        || blobName == "mat_stone"
        || blobName == "mat_wood"
        || blobName == "mat_bombs"
        || blobName == "mat_waterbombs"
        || blobName == "mat_arrows"
        || blobName == "mat_firearrows"
        || blobName == "mat_bombarrows"
        || blobName == "mat_waterarrows"
        || blobName == "log"
        || blobName == "fishy"
        || blobName == "grain"
        || blobName == "food"
        || blobName == "egg"
        || blobName == "mat_poisonarrows"// from here
        || blobName == "mat_spears"
        || blobName == "mat_firespears"
        || blobName == "mat_poisonspears"
        || blobName == "mat_smokeball"
        || blobName == "mat_bullets"
        || blobName == "mat_barricades"
        || blobName == "mat_medkits"
        || blobName == "mat_waterjar"
        || blobName == "mat_poisonjar"
        || blobName == "mat_acidjar"
        || blobName == "mat_poisonmeats"
        || blobName == "mat_cookingoils"
        || blobName == "mat_bombboxes"
        || blobName == "mat_boomerangs"
        || blobName == "mat_chakrams"
        || blobName == "mat_firelances"
        || blobName == "mat_flamethrowers"
        )
    {
        return this.server_PutInInventory(blob);
    }
    return false;
}
