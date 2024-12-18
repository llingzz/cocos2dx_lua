local RotationToSpeed = {
    [0]=cc.p(0,100),
    [1]=cc.p(1,99),
    [2]=cc.p(3,99),
    [3]=cc.p(5,99),
    [4]=cc.p(6,99),
    [5]=cc.p(8,99),
    [6]=cc.p(10,99),
    [7]=cc.p(12,99),
    [8]=cc.p(13,99),
    [9]=cc.p(15,98),
    [10]=cc.p(17,98),
    [11]=cc.p(19,98),
    [12]=cc.p(20,97),
    [13]=cc.p(22,97),
    [14]=cc.p(24,97),
    [15]=cc.p(25,96),
    [16]=cc.p(27,96),
    [17]=cc.p(29,95),
    [18]=cc.p(30,95),
    [19]=cc.p(32,94),
    [20]=cc.p(34,93),
    [21]=cc.p(35,93),
    [22]=cc.p(37,92),
    [23]=cc.p(39,92),
    [24]=cc.p(40,91),
    [25]=cc.p(42,90),
    [26]=cc.p(43,89),
    [27]=cc.p(45,89),
    [28]=cc.p(46,88),
    [29]=cc.p(48,87),
    [30]=cc.p(49,86),
    [31]=cc.p(51,85),
    [32]=cc.p(52,84),
    [33]=cc.p(54,83),
    [34]=cc.p(55,82),
    [35]=cc.p(57,81),
    [36]=cc.p(58,80),
    [37]=cc.p(60,79),
    [38]=cc.p(61,78),
    [39]=cc.p(62,77),
    [40]=cc.p(64,76),
    [41]=cc.p(65,75),
    [42]=cc.p(66,74),
    [43]=cc.p(68,73),
    [44]=cc.p(69,71),
    [45]=cc.p(70,70),
    [46]=cc.p(71,69),
    [47]=cc.p(73,68),
    [48]=cc.p(74,66),
    [49]=cc.p(75,65),
    [50]=cc.p(76,64),
    [51]=cc.p(77,62),
    [52]=cc.p(78,61),
    [53]=cc.p(79,60),
    [54]=cc.p(80,58),
    [55]=cc.p(81,57),
    [56]=cc.p(82,55),
    [57]=cc.p(83,54),
    [58]=cc.p(84,52),
    [59]=cc.p(85,51),
    [60]=cc.p(86,50),
    [61]=cc.p(87,48),
    [62]=cc.p(88,46),
    [63]=cc.p(89,45),
    [64]=cc.p(89,43),
    [65]=cc.p(90,42),
    [66]=cc.p(91,40),
    [67]=cc.p(92,39),
    [68]=cc.p(92,37),
    [69]=cc.p(93,35),
    [70]=cc.p(93,34),
    [71]=cc.p(94,32),
    [72]=cc.p(95,30),
    [73]=cc.p(95,29),
    [74]=cc.p(96,27),
    [75]=cc.p(96,25),
    [76]=cc.p(97,24),
    [77]=cc.p(97,22),
    [78]=cc.p(97,20),
    [79]=cc.p(98,19),
    [80]=cc.p(98,17),
    [81]=cc.p(98,15),
    [82]=cc.p(99,13),
    [83]=cc.p(99,12),
    [84]=cc.p(99,10),
    [85]=cc.p(99,8),
    [86]=cc.p(99,6),
    [87]=cc.p(99,5),
    [88]=cc.p(99,3),
    [89]=cc.p(99,1),
    [90]=cc.p(100,0),
    [91]=cc.p(99,-1),
    [92]=cc.p(99,-3),
    [93]=cc.p(99,-5),
    [94]=cc.p(99,-6),
    [95]=cc.p(99,-8),
    [96]=cc.p(99,-10),
    [97]=cc.p(99,-12),
    [98]=cc.p(99,-13),
    [99]=cc.p(98,-15),
    [100]=cc.p(98,-17),
    [101]=cc.p(98,-19),
    [102]=cc.p(97,-20),
    [103]=cc.p(97,-22),
    [104]=cc.p(97,-24),
    [105]=cc.p(96,-25),
    [106]=cc.p(96,-27),
    [107]=cc.p(95,-29),
    [108]=cc.p(95,-30),
    [109]=cc.p(94,-32),
    [110]=cc.p(93,-34),
    [111]=cc.p(93,-35),
    [112]=cc.p(92,-37),
    [113]=cc.p(92,-39),
    [114]=cc.p(91,-40),
    [115]=cc.p(90,-42),
    [116]=cc.p(89,-43),
    [117]=cc.p(89,-45),
    [118]=cc.p(88,-46),
    [119]=cc.p(87,-48),
    [120]=cc.p(86,-49),
    [121]=cc.p(85,-51),
    [122]=cc.p(84,-52),
    [123]=cc.p(83,-54),
    [124]=cc.p(82,-55),
    [125]=cc.p(81,-57),
    [126]=cc.p(80,-58),
    [127]=cc.p(79,-60),
    [128]=cc.p(78,-61),
    [129]=cc.p(77,-62),
    [130]=cc.p(76,-64),
    [131]=cc.p(75,-65),
    [132]=cc.p(74,-66),
    [133]=cc.p(73,-68),
    [134]=cc.p(71,-69),
    [135]=cc.p(70,-70),
    [136]=cc.p(69,-71),
    [137]=cc.p(68,-73),
    [138]=cc.p(66,-74),
    [139]=cc.p(65,-75),
    [140]=cc.p(64,-76),
    [141]=cc.p(62,-77),
    [142]=cc.p(61,-78),
    [143]=cc.p(60,-79),
    [144]=cc.p(58,-80),
    [145]=cc.p(57,-81),
    [146]=cc.p(55,-82),
    [147]=cc.p(54,-83),
    [148]=cc.p(52,-84),
    [149]=cc.p(51,-85),
    [150]=cc.p(49,-86),
    [151]=cc.p(48,-87),
    [152]=cc.p(46,-88),
    [153]=cc.p(45,-89),
    [154]=cc.p(43,-89),
    [155]=cc.p(42,-90),
    [156]=cc.p(40,-91),
    [157]=cc.p(39,-92),
    [158]=cc.p(37,-92),
    [159]=cc.p(35,-93),
    [160]=cc.p(34,-93),
    [161]=cc.p(32,-94),
    [162]=cc.p(30,-95),
    [163]=cc.p(29,-95),
    [164]=cc.p(27,-96),
    [165]=cc.p(25,-96),
    [166]=cc.p(24,-97),
    [167]=cc.p(22,-97),
    [168]=cc.p(20,-97),
    [169]=cc.p(19,-98),
    [170]=cc.p(17,-98),
    [171]=cc.p(15,-98),
    [172]=cc.p(13,-99),
    [173]=cc.p(12,-99),
    [174]=cc.p(10,-99),
    [175]=cc.p(8,-99),
    [176]=cc.p(6,-99),
    [177]=cc.p(5,-99),
    [178]=cc.p(3,-99),
    [179]=cc.p(1,-99),
    [180]=cc.p(0,-100),
    [181]=cc.p(-1,-99),
    [182]=cc.p(-3,-99),
    [183]=cc.p(-5,-99),
    [184]=cc.p(-6,-99),
    [185]=cc.p(-8,-99),
    [186]=cc.p(-10,-99),
    [187]=cc.p(-12,-99),
    [188]=cc.p(-13,-99),
    [189]=cc.p(-15,-98),
    [190]=cc.p(-17,-98),
    [191]=cc.p(-19,-98),
    [192]=cc.p(-20,-97),
    [193]=cc.p(-22,-97),
    [194]=cc.p(-24,-97),
    [195]=cc.p(-25,-96),
    [196]=cc.p(-27,-96),
    [197]=cc.p(-29,-95),
    [198]=cc.p(-30,-95),
    [199]=cc.p(-32,-94),
    [200]=cc.p(-34,-93),
    [201]=cc.p(-35,-93),
    [202]=cc.p(-37,-92),
    [203]=cc.p(-39,-92),
    [204]=cc.p(-40,-91),
    [205]=cc.p(-42,-90),
    [206]=cc.p(-43,-89),
    [207]=cc.p(-45,-89),
    [208]=cc.p(-46,-88),
    [209]=cc.p(-48,-87),
    [210]=cc.p(-50,-86),
    [211]=cc.p(-51,-85),
    [212]=cc.p(-52,-84),
    [213]=cc.p(-54,-83),
    [214]=cc.p(-55,-82),
    [215]=cc.p(-57,-81),
    [216]=cc.p(-58,-80),
    [217]=cc.p(-60,-79),
    [218]=cc.p(-61,-78),
    [219]=cc.p(-62,-77),
    [220]=cc.p(-64,-76),
    [221]=cc.p(-65,-75),
    [222]=cc.p(-66,-74),
    [223]=cc.p(-68,-73),
    [224]=cc.p(-69,-71),
    [225]=cc.p(-70,-70),
    [226]=cc.p(-71,-69),
    [227]=cc.p(-73,-68),
    [228]=cc.p(-74,-66),
    [229]=cc.p(-75,-65),
    [230]=cc.p(-76,-64),
    [231]=cc.p(-77,-62),
    [232]=cc.p(-78,-61),
    [233]=cc.p(-79,-60),
    [234]=cc.p(-80,-58),
    [235]=cc.p(-81,-57),
    [236]=cc.p(-82,-55),
    [237]=cc.p(-83,-54),
    [238]=cc.p(-84,-52),
    [239]=cc.p(-85,-51),
    [240]=cc.p(-86,-50),
    [241]=cc.p(-87,-48),
    [242]=cc.p(-88,-46),
    [243]=cc.p(-89,-45),
    [244]=cc.p(-89,-43),
    [245]=cc.p(-90,-42),
    [246]=cc.p(-91,-40),
    [247]=cc.p(-92,-39),
    [248]=cc.p(-92,-37),
    [249]=cc.p(-93,-35),
    [250]=cc.p(-93,-34),
    [251]=cc.p(-94,-32),
    [252]=cc.p(-95,-30),
    [253]=cc.p(-95,-29),
    [254]=cc.p(-96,-27),
    [255]=cc.p(-96,-25),
    [256]=cc.p(-97,-24),
    [257]=cc.p(-97,-22),
    [258]=cc.p(-97,-20),
    [259]=cc.p(-98,-19),
    [260]=cc.p(-98,-17),
    [261]=cc.p(-98,-15),
    [262]=cc.p(-99,-13),
    [263]=cc.p(-99,-12),
    [264]=cc.p(-99,-10),
    [265]=cc.p(-99,-8),
    [266]=cc.p(-99,-6),
    [267]=cc.p(-99,-5),
    [268]=cc.p(-99,-3),
    [269]=cc.p(-99,-1),
    [270]=cc.p(-100,0),
    [271]=cc.p(-99,1),
    [272]=cc.p(-99,3),
    [273]=cc.p(-99,5),
    [274]=cc.p(-99,6),
    [275]=cc.p(-99,8),
    [276]=cc.p(-99,10),
    [277]=cc.p(-99,12),
    [278]=cc.p(-99,13),
    [279]=cc.p(-98,15),
    [280]=cc.p(-98,17),
    [281]=cc.p(-98,19),
    [282]=cc.p(-97,20),
    [283]=cc.p(-97,22),
    [284]=cc.p(-97,24),
    [285]=cc.p(-96,25),
    [286]=cc.p(-96,27),
    [287]=cc.p(-95,29),
    [288]=cc.p(-95,30),
    [289]=cc.p(-94,32),
    [290]=cc.p(-93,34),
    [291]=cc.p(-93,35),
    [292]=cc.p(-92,37),
    [293]=cc.p(-92,39),
    [294]=cc.p(-91,40),
    [295]=cc.p(-90,42),
    [296]=cc.p(-89,43),
    [297]=cc.p(-89,45),
    [298]=cc.p(-88,46),
    [299]=cc.p(-87,48),
    [300]=cc.p(-86,50),
    [301]=cc.p(-85,51),
    [302]=cc.p(-84,52),
    [303]=cc.p(-83,54),
    [304]=cc.p(-82,55),
    [305]=cc.p(-81,57),
    [306]=cc.p(-80,58),
    [307]=cc.p(-79,60),
    [308]=cc.p(-78,61),
    [309]=cc.p(-77,62),
    [310]=cc.p(-76,64),
    [311]=cc.p(-75,65),
    [312]=cc.p(-74,66),
    [313]=cc.p(-73,68),
    [314]=cc.p(-71,69),
    [315]=cc.p(-70,70),
    [316]=cc.p(-69,71),
    [317]=cc.p(-68,73),
    [318]=cc.p(-66,74),
    [319]=cc.p(-65,75),
    [320]=cc.p(-64,76),
    [321]=cc.p(-62,77),
    [322]=cc.p(-61,78),
    [323]=cc.p(-60,79),
    [324]=cc.p(-58,80),
    [325]=cc.p(-57,81),
    [326]=cc.p(-55,82),
    [327]=cc.p(-54,83),
    [328]=cc.p(-52,84),
    [329]=cc.p(-51,85),
    [330]=cc.p(-50,86),
    [331]=cc.p(-48,87),
    [332]=cc.p(-46,88),
    [333]=cc.p(-45,89),
    [334]=cc.p(-43,89),
    [335]=cc.p(-42,90),
    [336]=cc.p(-40,91),
    [337]=cc.p(-39,92),
    [338]=cc.p(-37,92),
    [339]=cc.p(-35,93),
    [340]=cc.p(-34,93),
    [341]=cc.p(-32,94),
    [342]=cc.p(-30,95),
    [343]=cc.p(-29,95),
    [344]=cc.p(-27,96),
    [345]=cc.p(-25,96),
    [346]=cc.p(-24,97),
    [347]=cc.p(-22,97),
    [348]=cc.p(-20,97),
    [349]=cc.p(-19,98),
    [350]=cc.p(-17,98),
    [351]=cc.p(-15,98),
    [352]=cc.p(-13,99),
    [353]=cc.p(-12,99),
    [354]=cc.p(-10,99),
    [355]=cc.p(-8,99),
    [356]=cc.p(-6,99),
    [357]=cc.p(-5,99),
    [358]=cc.p(-3,99),
    [359]=cc.p(-1,99),
    [360]=cc.p(0,100),
}

return RotationToSpeed