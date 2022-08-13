let strArray = [302,151,631,315,713,912,1011,1061,1086,543,827,969,1040,520,260,130,65,588,294,702,906,1008,504,807,403,201,100,50,580,290,145,72,591,851,981,1046,523,261,686,343,727,919,459,785,392,196,98,604,706,908,454,227,669,334,167,83,597,298,704,352,731,921,1016,1063,531,265,132,66,147,73,592,425,768,939,469,790,950];

let findDuplicates = arr => arr.filter((item, index) => arr.indexOf(item) != index)

console.log(findDuplicates(strArray)) // All duplicates
console.log([...new Set(findDuplicates(strArray))]) // Unique duplicates