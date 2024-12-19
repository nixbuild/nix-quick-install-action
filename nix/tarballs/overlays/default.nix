# deadnix: skip
{ inputs, cell }:
{
  prefer-remote-fetch = final: prev: prev.prefer-remote-fetch final prev;
}
