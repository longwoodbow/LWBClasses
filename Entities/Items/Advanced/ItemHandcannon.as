
void onInit(CBlob@ this)
{
  this.set_string("required class", "handcannon");
  this.set_string("description", "Handcannon");
  this.getCurrentScript().runFlags |= Script::remove_after_this;
}