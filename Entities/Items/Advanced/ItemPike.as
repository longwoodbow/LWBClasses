
void onInit(CBlob@ this)
{
  this.set_string("required class", "pikeman");
  this.set_string("description", "Pikeman");
  this.getCurrentScript().runFlags |= Script::remove_after_this;
}