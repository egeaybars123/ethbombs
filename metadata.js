var fs = require('fs');

var color_array = ["Blue", "Green", "Orange", "Pink", "Purple", "Red", "Yellow"];

for (var i = 0; i < 7; i++) {
  var json = {}
  json.name = color_array[i] + " Bomb";
  json.description = color_array[i] + " Bomb for the ETHBombs collection";
  json.image = "ipfs://bafybeiaavedyvag4272mtpg2b24qm3uf4f366irzd7b4x5hedai7362okm/" + (i + 1) + ".gif";

  fs.writeFileSync('' + (i+1), JSON.stringify(json));
}
