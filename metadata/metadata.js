var fs = require('fs');

var color_array = ["Blue", "Green", "Orange", "Pink", "Purple", "Red", "Yellow", "Exploded", "0.25 ETH Winner", "1 ETH Winner"];

for (var i = 0; i < color_array.length; i++) {
  var json = {}
  json.name = color_array[i] + " Bomb";
  json.description = color_array[i] + " Bomb for the ETHBombs collection";
  json.image = "ipfs://bafybeie4gaak6q3jfmgdarhitneb6mofi2p3l5ycld6thdbf6rvofmmwli/" + (i + 1) + ".gif";

  fs.writeFileSync('' + (i+1), JSON.stringify(json));
}
