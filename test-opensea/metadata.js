var fs = require('fs');

var color_array = ["Blue", "Green", "Orange", "Pink", "Purple", "Red", "Yellow", "Exploded", "0.1 ETH Winner", "0.5 ETH Winner", "7 ETH Winner"];

for (var i = 0; i < color_array.length; i++) {
  var json = {}
  json.name = color_array[i] + " Bomb";
  json.description = color_array[i] + " Bomb for the ETHBombs collection";
  json.image = "ipfs://bafybeid3s2d2g452wve3a2o3gcwzv72r53n3fcjpq7hm56hvn7ilycsmva/" + (i + 1) + ".gif";

  fs.writeFileSync('' + (i+1), JSON.stringify(json));
}
