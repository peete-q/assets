return {
  ["Sm_Bomber_Escort"] = {
    _id = "Sm_Bomber_Escort",
    kind = "sb",
    cost = 32,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 4,
        disc = "low",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Sm_Bomber",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Med_Bomber_Escort"] = {
    _id = "Med_Bomber_Escort",
    kind = "mb",
    cost = 40,
    ranges = {
      [1] = {
        10,
        15,
        30,
        35
      }
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Med_Fighter",
        qty = 3,
        disc = "high",
        eng = "flyover",
        brv = 50
      },
      {
        id = "Alien_Med_Bomber",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["4_Sm_Fighters"] = {
    _id = "4_Sm_Fighters",
    kind = "sf",
    cost = 12,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 4,
        disc = "low",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Bertha_Escort"] = {
    _id = "Bertha_Escort",
    kind = "ss",
    cost = 94,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Med_Artillery",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 4,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["3_Med_Fighters"] = {
    _id = "3_Med_Fighters",
    kind = "mf",
    cost = 15,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Med_Fighter",
        qty = 3,
        disc = "low",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["1_Med_Fighter"] = {
    _id = "1_Med_Fighter",
    kind = "mf",
    cost = 5,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Med_Fighter",
        qty = 1,
        disc = "low",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["1_Sm_Fighter"] = {
    _id = "1_Sm_Fighter",
    kind = "sf",
    cost = 3,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 1,
        disc = "low",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Lg_Bomber"] = {
    _id = "Lg_Bomber",
    kind = "lb",
    cost = 34,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {11, 14},
    ships = {
      {
        id = "Alien_Lg_Bomber",
        qty = 1,
        disc = "med",
        eng = "bombard",
        brv = 100
      }
    }
  },
  ["Sm_Bomber"] = {
    _id = "Sm_Bomber",
    kind = "sb",
    cost = 20,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Sm_Bomber",
        qty = 1,
        disc = "med",
        eng = "flyover2",
        brv = 100
      }
    }
  },
  ["Lg_Bomber_Escort"] = {
    _id = "Lg_Bomber_Escort",
    kind = "ilb",
    cost = 54,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Lg_Bomber",
        qty = 1,
        disc = "med",
        eng = "bombard",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 4,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Buzz_Fighters"] = {
    _id = "Buzz_Fighters",
    kind = "sf",
    cost = 9,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 3,
        disc = "low",
        eng = "flyover",
        brv = 25
      }
    }
  },
  ["Diamond_Formation"] = {
    _id = "Diamond_Formation",
    kind = "xf",
    cost = 16,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 2,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 2,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Blue_Angels"] = {
    _id = "Blue_Angels",
    kind = "xf",
    cost = 24,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 3,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 3,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["The_swarm"] = {
    _id = "The_swarm",
    kind = "xf",
    cost = 40,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 5,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 5,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["1_Lg_Fighter"] = {
    _id = "1_Lg_Fighter",
    kind = "lf",
    cost = 11,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Large_Fighter",
        qty = 1,
        disc = "med",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["3_Lg_Fighters"] = {
    _id = "3_Lg_Fighters",
    kind = "lf",
    cost = 33,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Large_Fighter",
        qty = 3,
        disc = "med",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["All_three"] = {
    _id = "All_three",
    kind = "xf",
    cost = 19,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Intro_Small_Bomber"] = {
    _id = "Intro_Small_Bomber",
    kind = "isb",
    cost = 44,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Sm_Bomber",
        qty = 1,
        disc = "high",
        eng = "flyover2",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 3,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 3,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Anti_Fighter_Siege"] = {
    _id = "Anti_Fighter_Siege",
    kind = "afs",
    cost = 169,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Con_Ballista",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Con_Ballista",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Con_Ballista",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 5,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Anti_CapShip_Siege"] = {
    _id = "Anti_CapShip_Siege",
    kind = "acs",
    cost = 202,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Con_Trebuchet",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Con_Trebuchet",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Con_Trebuchet",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 5,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Anti_Asteroid_Siege"] = {
    _id = "Anti_Asteroid_Siege",
    kind = "aas",
    cost = 106,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Con_Catapult",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Con_Catapult",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Con_Catapult",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 5,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Small_Bomber Squad"] = {
    _id = "Small_Bomber Squad",
    kind = "sb",
    cost = 60,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Sm_Bomber",
        qty = 3,
        disc = "high",
        eng = "bombard",
        brv = 100
      }
    }
  },
  ["Intro_Med_Bomber"] = {
    _id = "Intro_Med_Bomber",
    kind = "imb",
    cost = 49,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Med_Bomber",
        qty = 1,
        disc = "high",
        eng = "flyover2",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 3,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 3,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Anti_Asteroid_Siege2"] = {
    _id = "Anti_Asteroid_Siege2",
    kind = "aas2",
    cost = 212,
    ranges = {
      [1] = {1, 40}
    },
    minSurvialArc = {10, 14},
    ships = {
      {
        id = "Alien_Con_Catapult",
        qty = 1,
        disc = "high",
        eng = "build",
        brv = 100
      },
      {
        id = "Alien_Con_Catapult",
        qty = 1,
        disc = "high",
        eng = "build",
        brv = 100
      },
      {
        id = "Alien_Con_Catapult",
        qty = 1,
        disc = "high",
        eng = "build",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 5,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Beginning_Sm_Fighters1"] = {
    _id = "Beginning_Sm_Fighters1",
    kind = "bsf1",
    cost = 9,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 3,
        disc = "high",
        eng = "wail",
        brv = 100
      }
    }
  },
  ["Beginning_Sm_Fighters2"] = {
    _id = "Beginning_Sm_Fighters2",
    kind = "bsf2",
    cost = 18,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 6,
        disc = "high",
        eng = "wail",
        brv = 100
      }
    }
  },
  ["Beginning_Sm_Fighters3"] = {
    _id = "Beginning_Sm_Fighters3",
    kind = "bsf3",
    cost = 27,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 9,
        disc = "high",
        eng = "wail",
        brv = 100
      }
    }
  },
  ["Beginning_Med_Fighters1"] = {
    _id = "Beginning_Med_Fighters1",
    kind = "bmf1",
    cost = 10,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Med_Fighter",
        qty = 2,
        disc = "high",
        eng = "wail",
        brv = 100
      }
    }
  },
  ["Beginning_Med_Fighters2"] = {
    _id = "Beginning_Med_Fighters2",
    kind = "bmf2",
    cost = 25,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Med_Fighter",
        qty = 5,
        disc = "high",
        eng = "wail",
        brv = 100
      }
    }
  },
  ["Beginning_3_Lg_Fighters"] = {
    _id = "Beginning_3_Lg_Fighters",
    kind = "blf",
    cost = 33,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Large_Fighter",
        qty = 3,
        disc = "high",
        eng = "wail",
        brv = 100
      }
    }
  },
  ["Shield_Med_Fighters"] = {
    _id = "Shield_Med_Fighters",
    kind = "shmf",
    cost = 18,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Med_Fighter_SH",
        qty = 3,
        disc = "high",
        eng = "wail",
        brv = 100
      }
    }
  },
  ["Shield_Large_Fighters"] = {
    _id = "Shield_Large_Fighters",
    kind = "shlf",
    cost = 28,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Large_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "wail",
        brv = 100
      }
    }
  },
  ["Bertha_Shields_Escort"] = {
    _id = "Bertha_Shields_Escort",
    kind = "shss",
    cost = 112,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Med_Artillery_SH",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 4,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Bertha_Escort"] = {
    _id = "Bertha_Escort",
    kind = "ss",
    cost = 94,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Med_Artillery",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 4,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Large_Bomb_B"] = {
    _id = "Shield_Large_Bomb_B",
    kind = "shlb",
    cost = 76,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Lg_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Med_Bomb_B"] = {
    _id = "Shield_Med_Bomb_B",
    kind = "shmb",
    cost = 48,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Med_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Sm_Bomb_B"] = {
    _id = "Shield_Sm_Bomb_B",
    kind = "shsb",
    cost = 41,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Sm_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Large_Bomb_All"] = {
    _id = "Shield_Large_Bomb_All",
    kind = "shlb",
    cost = 84,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Lg_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Med_Bomb_All"] = {
    _id = "Shield_Med_Bomb_All",
    kind = "shmb",
    cost = 72,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Med_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Sm_Bomb_All"] = {
    _id = "Shield_Sm_Bomb_All",
    kind = "shsb",
    cost = 65,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Sm_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Large_Bomb"] = {
    _id = "Shield_Large_Bomb",
    kind = "shlb",
    cost = 44,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Lg_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      }
    }
  },
  ["Shield_Med_Bomb"] = {
    _id = "Shield_Med_Bomb",
    kind = "shmb",
    cost = 32,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Med_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Shield_Sm_Bomb"] = {
    _id = "Shield_Sm_Bomb",
    kind = "shsb",
    cost = 25,
    ranges = {
      [1] = {1, 40}
    },
    ships = {
      {
        id = "Alien_Sm_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Sm_Bomber_Escort_vMix"] = {
    _id = "Sm_Bomber_Escort_vMix",
    kind = "sb",
    cost = 54,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 4,
        disc = "low",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Sm_Bomber",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      }
    }
  },
  ["Med_Bomber_Escort_vMix"] = {
    _id = "Med_Bomber_Escort_vMix",
    kind = "mb",
    cost = 69,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Med_Fighter_v2",
        qty = 3,
        disc = "high",
        eng = "flyover",
        brv = 50
      },
      {
        id = "Alien_Med_Bomber",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      }
    }
  },
  ["4_Sm_Fighters_vMix"] = {
    _id = "4_Sm_Fighters_vMix",
    kind = "sf",
    cost = 28,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 2,
        disc = "low",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 2,
        disc = "low",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Bertha_Escort_vMix"] = {
    _id = "Bertha_Escort_vMix",
    kind = "ss",
    cost = 116,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Med_Artillery",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 4,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["3_Med_Fighters_vMix"] = {
    _id = "3_Med_Fighters_vMix",
    kind = "mf",
    cost = 28,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Med_Fighter_v2",
        qty = 1,
        disc = "low",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 2,
        disc = "low",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Lg_Bomber_Escort_vMix"] = {
    _id = "Lg_Bomber_Escort_vMix",
    kind = "lb",
    cost = 80,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Lg_Bomber",
        qty = 1,
        disc = "med",
        eng = "bombard",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 4,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Buzz_Fighters_vMix"] = {
    _id = "Buzz_Fighters_vMix",
    kind = "sf",
    cost = 25,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 1,
        disc = "low",
        eng = "flyover",
        brv = 25
      },
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 2,
        disc = "low",
        eng = "flyover",
        brv = 25
      }
    }
  },
  ["Diamond_Formation_vMix"] = {
    _id = "Diamond_Formation_vMix",
    kind = "xf",
    cost = 42,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 2,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 2,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Blue_Angels_vMix"] = {
    _id = "Blue_Angels_vMix",
    kind = "xf",
    cost = 59,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 3,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 3,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["The_swarm_vMix"] = {
    _id = "The_swarm_vMix",
    kind = "xf",
    cost = 95,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Sm_Fighter",
        qty = 5,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 5,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["3_Lg_Fighters_vMix"] = {
    _id = "3_Lg_Fighters_vMix",
    kind = "lf",
    cost = 95,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Large_Fighter_v2",
        qty = 2,
        disc = "med",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter",
        qty = 1,
        disc = "med",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["All_three_vMix"] = {
    _id = "All_three_vMix",
    kind = "xf",
    cost = 84,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Small_Bomber Squad_vMix"] = {
    _id = "Small_Bomber Squad_vMix",
    kind = "sb",
    cost = 91,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Sm_Bomber",
        qty = 2,
        disc = "high",
        eng = "bombard",
        brv = 100
      },
      {
        id = "Alien_Sm_Bomber_v2",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      }
    }
  },
  ["Shield_Med_Fighters_vMix"] = {
    _id = "Shield_Med_Fighters_vMix",
    kind = "mf",
    cost = 75,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Med_Fighter_SH_v2",
        qty = 3,
        disc = "high",
        eng = "wail",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_SH",
        qty = 1,
        disc = "high",
        eng = "wail",
        brv = 100
      }
    }
  },
  ["Bertha_Shields_Escort_vMix"] = {
    _id = "Bertha_Shields_Escort_vMix",
    kind = "ss",
    cost = 112,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Med_Artillery_SH",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 4,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Large_Bomb_B_vMix"] = {
    _id = "Shield_Large_Bomb_B_vMix",
    kind = "lb",
    cost = 140,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Lg_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Med_Bomb_B_vMix"] = {
    _id = "Shield_Med_Bomb_B_vMix",
    kind = "mb",
    cost = 64,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Med_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Sm_Bomb_B_vMix"] = {
    _id = "Shield_Sm_Bomb_B_vMix",
    kind = "sb",
    cost = 67,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Sm_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Large_Bomb_All_vMix"] = {
    _id = "Shield_Large_Bomb_All_vMix",
    kind = "lb",
    cost = 90,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Lg_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_SH_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Med_Bomb_All_vMix"] = {
    _id = "Shield_Med_Bomb_All_vMix",
    kind = "mb",
    cost = 142,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Med_Bomber_SH_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Sm_Bomb_All_vMix"] = {
    _id = "Shield_Sm_Bomb_All_vMix",
    kind = "sb",
    cost = 125,
    ranges = {},
    minSurvialArc = {11, 22},
    ships = {
      {
        id = "Alien_Sm_Bomber_SH_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Sm_Bomber_Escort_v2"] = {
    _id = "Sm_Bomber_Escort_v2",
    kind = "sb",
    cost = 94,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 4,
        disc = "low",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Sm_Bomber_v2",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      }
    }
  },
  ["Med_Bomber_Escort_v2"] = {
    _id = "Med_Bomber_Escort_v2",
    kind = "mb",
    cost = 123,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Med_Fighter_v2",
        qty = 3,
        disc = "high",
        eng = "flyover",
        brv = 50
      },
      {
        id = "Alien_Med_Bomber_v2",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      }
    }
  },
  ["4_Sm_Fighters_v2"] = {
    _id = "4_Sm_Fighters_v2",
    kind = "sf",
    cost = 44,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 4,
        disc = "low",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["3_Med_Fighters_v2"] = {
    _id = "3_Med_Fighters_v2",
    kind = "mf",
    cost = 54,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Med_Fighter_v2",
        qty = 3,
        disc = "low",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["1_Med_Fighter_v2"] = {
    _id = "1_Med_Fighter_v2",
    kind = "mf",
    cost = 18,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Med_Fighter_v2",
        qty = 1,
        disc = "low",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["1_Sm_Fighter_v2"] = {
    _id = "1_Sm_Fighter_v2",
    kind = "sf",
    cost = 11,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 1,
        disc = "low",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Lg_Bomber_v2"] = {
    _id = "Lg_Bomber_v2",
    kind = "lb",
    cost = 144,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Lg_Bomber_v2",
        qty = 1,
        disc = "med",
        eng = "bombard",
        brv = 100
      }
    }
  },
  ["Sm_Bomber_v2"] = {
    _id = "Sm_Bomber_v2",
    kind = "sb",
    cost = 55,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Sm_Bomber_v2",
        qty = 1,
        disc = "med",
        eng = "flyover2",
        brv = 100
      }
    }
  },
  ["Lg_Bomber_Escort_v2"] = {
    _id = "Lg_Bomber_Escort_v2",
    kind = "lb",
    cost = 183,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Lg_Bomber_v2",
        qty = 1,
        disc = "med",
        eng = "bombard",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 4,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Buzz_Fighters_v2"] = {
    _id = "Buzz_Fighters_v2",
    kind = "sf",
    cost = 33,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 3,
        disc = "low",
        eng = "flyover",
        brv = 25
      }
    }
  },
  ["Diamond_Formation_v2"] = {
    _id = "Diamond_Formation_v2",
    kind = "xf",
    cost = 58,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 2,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 2,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Blue_Angels_v2"] = {
    _id = "Blue_Angels_v2",
    kind = "xf",
    cost = 72,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 3,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 3,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["The_swarm_v2"] = {
    _id = "The_swarm_v2",
    kind = "xf",
    cost = 135,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 5,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 5,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["1_Lg_Fighter_v2"] = {
    _id = "1_Lg_Fighter_v2",
    kind = "lf",
    cost = 47,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Large_Fighter_v2",
        qty = 1,
        disc = "med",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["3_Lg_Fighters_v2"] = {
    _id = "3_Lg_Fighters_v2",
    kind = "lf",
    cost = 130,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Large_Fighter_v2",
        qty = 3,
        disc = "med",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["All_three_v2"] = {
    _id = "All_three_v2",
    kind = "xf",
    cost = 76,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Screamers"] = {
    _id = "Screamers",
    kind = "xf",
    cost = 32,
    ranges = {},
    minSurvialArc = {11, 50},
    ships = {
      {
        id = "Alien_Med_Fighter_v2_screamer",
        qty = 3,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Anti_Fighter_Siege_v2"] = {
    _id = "Anti_Fighter_Siege_v2",
    kind = "afs",
    cost = 150,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Con_Ballista_v2",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Con_Ballista_v2",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Con_Ballista_v2",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 5,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Anti_CapShip_Siege_v2"] = {
    _id = "Anti_CapShip_Siege_v2",
    kind = "acs",
    cost = 150,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Con_Trebuchet_v2",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Con_Trebuchet_v2",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Con_Trebuchet_v2",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 5,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Small_Bomber Squad_v2"] = {
    _id = "Small_Bomber Squad_v2",
    kind = "sb",
    cost = 180,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Sm_Bomber_v2",
        qty = 3,
        disc = "high",
        eng = "bombard",
        brv = 100
      }
    }
  },
  ["Shield_Med_Fighters_v2"] = {
    _id = "Shield_Med_Fighters_v2",
    kind = "mf",
    cost = 69,
    ranges = {},
    minSurvialArc = {20, 50},
    ships = {
      {
        id = "Alien_Med_Fighter_SH_v2",
        qty = 3,
        disc = "high",
        eng = "wail",
        brv = 100
      }
    }
  },
  ["Shield_Large_Fighters_v2"] = {
    _id = "Shield_Large_Fighters_v2",
    kind = "lf",
    cost = 124,
    ranges = {},
    minSurvialArc = {25, 50},
    ships = {
      {
        id = "Alien_Large_Fighter_SH_v2",
        qty = 2,
        disc = "high",
        eng = "wail",
        brv = 100
      }
    }
  },
  ["Bertha_Shields_Escort_v2"] = {
    _id = "Bertha_Shields_Escort_v2",
    kind = "ss",
    cost = 250,
    ranges = {},
    minSurvialArc = {20, 50},
    ships = {
      {
        id = "Alien_Med_Artillery_SH_v2",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 4,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Bertha_Escort_v2"] = {
    _id = "Bertha_Escort_v2",
    kind = "ss",
    cost = 200,
    ranges = {},
    minSurvialArc = {18, 50},
    ships = {
      {
        id = "Alien_Med_Artillery_v2",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 4,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Large_Bomb_B_v2"] = {
    _id = "Shield_Large_Bomb_B_v2",
    kind = "lb",
    cost = 200,
    ranges = {},
    minSurvialArc = {20, 50},
    ships = {
      {
        id = "Alien_Lg_Bomber_SH_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Med_Bomb_B_v2"] = {
    _id = "Shield_Med_Bomb_B_v2",
    kind = "mb",
    cost = 170,
    ranges = {},
    minSurvialArc = {20, 50},
    ships = {
      {
        id = "Alien_Med_Bomber_SH_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Sm_Bomb_B_v2"] = {
    _id = "Shield_Sm_Bomb_B_v2",
    kind = "sb",
    cost = 143,
    ranges = {},
    minSurvialArc = {20, 50},
    ships = {
      {
        id = "Alien_Sm_Bomber_SH_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Large_Bomb_All_v2"] = {
    _id = "Shield_Large_Bomb_All_v2",
    kind = "lb",
    cost = 250,
    ranges = {},
    minSurvialArc = {20, 50},
    ships = {
      {
        id = "Alien_Lg_Bomber_SH_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_SH_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_SH_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Med_Bomb_All_v2"] = {
    _id = "Shield_Med_Bomb_All_v2",
    kind = "mb",
    cost = 225,
    ranges = {},
    minSurvialArc = {20, 50},
    ships = {
      {
        id = "Alien_Med_Bomber_SH_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_SH_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_SH_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Sm_Bomb_All_v2"] = {
    _id = "Shield_Sm_Bomb_All_v2",
    kind = "sb",
    cost = 200,
    ranges = {},
    minSurvialArc = {20, 50},
    ships = {
      {
        id = "Alien_Sm_Bomber_SH_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_SH_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_SH_v2",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Large_Bomb_v2"] = {
    _id = "Shield_Large_Bomb_v2",
    kind = "lb",
    cost = 150,
    ranges = {},
    minSurvialArc = {20, 50},
    ships = {
      {
        id = "Alien_Lg_Bomber_SH_v2",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      }
    }
  },
  ["Shield_Med_Bomb_v2"] = {
    _id = "Shield_Med_Bomb_v2",
    kind = "mb",
    cost = 112,
    ranges = {},
    minSurvialArc = {20, 50},
    ships = {
      {
        id = "Alien_Med_Bomber_SH_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Shield_Sm_Bomb_v2"] = {
    _id = "Shield_Sm_Bomb_v2",
    kind = "sb",
    cost = 85,
    ranges = {},
    minSurvialArc = {20, 50},
    ships = {
      {
        id = "Alien_Sm_Bomber_SH_v2",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Shield_Med_Fighters_surv"] = {
    _id = "Shield_Med_Fighters_surv",
    kind = "mf",
    cost = 18,
    ranges = {},
    minSurvialArc = {12, 22},
    ships = {
      {
        id = "Alien_Med_Fighter_SH",
        qty = 3,
        disc = "high",
        eng = "wail",
        brv = 100
      }
    }
  },
  ["Shield_Large_Fighters_surv"] = {
    _id = "Shield_Large_Fighters_surv",
    kind = "lf",
    cost = 28,
    ranges = {},
    minSurvialArc = {12, 22},
    ships = {
      {
        id = "Alien_Large_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "wail",
        brv = 100
      }
    }
  },
  ["Bertha_Shields_Escort_surv"] = {
    _id = "Bertha_Shields_Escort_surv",
    kind = "ss",
    cost = 105,
    ranges = {},
    minSurvialArc = {12, 22},
    ships = {
      {
        id = "Alien_Med_Artillery_SH",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 4,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Large_Bomb_B_surv"] = {
    _id = "Shield_Large_Bomb_B_surv",
    kind = "lb",
    cost = 76,
    ranges = {},
    minSurvialArc = {12, 20},
    ships = {
      {
        id = "Alien_Lg_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Med_Bomb_B_surv"] = {
    _id = "Shield_Med_Bomb_B_surv",
    kind = "mb",
    cost = 48,
    ranges = {},
    minSurvialArc = {12, 20},
    ships = {
      {
        id = "Alien_Med_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Sm_Bomb_B_surv"] = {
    _id = "Shield_Sm_Bomb_B_surv",
    kind = "sb",
    cost = 41,
    ranges = {},
    minSurvialArc = {12, 20},
    ships = {
      {
        id = "Alien_Sm_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Large_Bomb_All_surv"] = {
    _id = "Shield_Large_Bomb_All_surv",
    kind = "lb",
    cost = 74,
    ranges = {},
    minSurvialArc = {12, 20},
    ships = {
      {
        id = "Alien_Lg_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Med_Bomb_All_surv"] = {
    _id = "Shield_Med_Bomb_All_surv",
    kind = "mb",
    cost = 61,
    ranges = {},
    minSurvialArc = {12, 20},
    ships = {
      {
        id = "Alien_Med_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Sm_Bomb_All_surv"] = {
    _id = "Shield_Sm_Bomb_All_surv",
    kind = "sb",
    cost = 55,
    ranges = {},
    minSurvialArc = {12, 20},
    ships = {
      {
        id = "Alien_Sm_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      },
      {
        id = "Alien_Large_Fighter_SH",
        qty = 2,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Shield_Large_Bomb_surv"] = {
    _id = "Shield_Large_Bomb_surv",
    kind = "lb",
    cost = 44,
    ranges = {},
    minSurvialArc = {12, 20},
    ships = {
      {
        id = "Alien_Lg_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      }
    }
  },
  ["Shield_Med_Bomb_surv"] = {
    _id = "Shield_Med_Bomb_surv",
    kind = "mb",
    cost = 32,
    ranges = {},
    minSurvialArc = {12, 20},
    ships = {
      {
        id = "Alien_Med_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Shield_Sm_Bomb_surv"] = {
    _id = "Shield_Sm_Bomb_surv",
    kind = "sb",
    cost = 25,
    ranges = {},
    minSurvialArc = {12, 20},
    ships = {
      {
        id = "Alien_Sm_Bomber_SH",
        qty = 1,
        disc = "high",
        eng = "flyover",
        brv = 100
      }
    }
  },
  ["Anti_Fighter_Siege_surv"] = {
    _id = "Anti_Fighter_Siege_surv",
    kind = "afs",
    cost = 120,
    ranges = {},
    minSurvialArc = {11, 15},
    ships = {
      {
        id = "Alien_Con_Ballista",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Con_Ballista",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Con_Ballista",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 5,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Anti_CapShip_Siege_surv"] = {
    _id = "Anti_CapShip_Siege_surv",
    kind = "acs",
    cost = 120,
    ranges = {},
    minSurvialArc = {11, 15},
    ships = {
      {
        id = "Alien_Con_Trebuchet",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Con_Trebuchet",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Con_Trebuchet",
        qty = 1,
        disc = "high",
        eng = "buildonce",
        brv = 100
      },
      {
        id = "Alien_Med_Fighter",
        qty = 5,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  },
  ["Bertha_Escort_surv"] = {
    _id = "Bertha_Escort_surv",
    kind = "ss",
    cost = 83,
    ranges = {},
    minSurvialArc = {10, 15},
    ships = {
      {
        id = "Alien_Med_Artillery",
        qty = 1,
        disc = "high",
        eng = "bombard",
        brv = 100
      },
      {
        id = "Alien_Sm_Fighter",
        qty = 4,
        disc = "high",
        eng = "protect",
        brv = 100
      }
    }
  }
}
