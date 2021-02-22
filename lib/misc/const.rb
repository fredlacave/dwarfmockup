#! /usr/local/bin/ruby
# encoding: utf-8

DWARFMOCKUP_VERSION = '1.2'

NT = 256
GRIDS = 15
GRID_LEVEL_0 = 7

KEY_PRESS = 50
KEY_REPEAT = 150

DKEYS = [ Gosu::Button::KbLeftShift, Gosu::Button::KbRightShift,
          Gosu::Button::KbLeftAlt, Gosu::Button::KbRightAlt,
          Gosu::Button::KbLeftControl, Gosu::Button::KbRightControl ]

CKEYS = [ [ Gosu::Button::KbNumpad1 ],
          [ Gosu::Button::KbNumpad2, Gosu::Button::KbDown ],
          [ Gosu::Button::KbNumpad3 ],
          [ Gosu::Button::KbNumpad4, Gosu::Button::KbLeft ],
          [],
          [ Gosu::Button::KbNumpad6, Gosu::Button::KbRight ],
          [ Gosu::Button::KbNumpad7 ],
          [ Gosu::Button::KbNumpad8, Gosu::Button::KbUp ],
          [ Gosu::Button::KbNumpad9 ] ]
DIRS = [ [ -1,  1 ],
         [  0,  1 ],
         [  1,  1 ],
         [ -1,  0 ],
         [  0,  0 ],
         [  1,  0 ],
         [ -1, -1 ],
         [  0, -1 ],
         [  1, -1 ] ]

HELP = {
    :design => [
        "== Room design ================",
        "-- Excavation -----------------",
        "d : dig",
        "h : hole",
        "x : fill",
        "j : down stairs",
        "i : updown stairs",
        "u : up stairs",
        "r : up ramp",
        "v : down ramp",
        "",
        "-- Decoration -----------------",
        "t : dirt",
        "g : rough",
        "s : smooth",
        "e : engrave",
        "q : fortification",
        "",
        "-- Building -----------------",
        "w : wall",
        "a : fortification",
        "f : floor",
    ],
    :items => [
        "== Items ======================",
        "-- Furniture ------------------",
        "b : bed",
        "t : table",
        "c : chair",
        "h : chest",
        "n : cabinet",
        "r : weapon rack",
        "a : armor stand",
        "s : statue",
        "w : well",
        "l : lever",
        "p : trap",
        "m : coffin",
        "",
        "-- Doors ----------------------",
        "d : door",
        "g : grid / bars",
        "z : horizontal bars",
        "f : floodgate",
        "y : hatch",
        "",
        "-- Stairs ---------------------",
        "u : up stair",
        "j : down stair",
        "o : up/down stair",
        "",
        "-- Other ----------------------",
        "x : delete",
    ],
    :stockpiles => [
        "== Stockpiles =================",
        "-- Command --------------------",
        "p : place",
        "x : delete",
    ],
    :adjustments => [
        "== Adjustments ================",
        "-- Command --------------------",
        "p : place",
        "x : delete",
    ],
    :copy => [
        "== Copy =======================",
    ],
    :cut => [
        "== Cut ========================",
    ],
}

SEL_HELP = [
    "",
    "== Selection mode =============",
    "R : full rectangle",
    "C : contour",
    "O : one cell",
    "E : full ellipse",
    "Z : ellipse contour",
    "L : line",
    "P : protect",
    "",
    "== Other ======================",
    "N : previous main mode",
    "M : next main mode",
    "Ctrl-H : help & other keys",
]

MODE = HELP.inject({}) do |h, e|
  h[e[0]] = e[1].inject([]) { |sa, l| sa << $1 if l =~ /^([A-Za-z])/ ; sa }.compact
  h
end

MAIN_MODES = HELP.keys - [ :cut, :copy, :paste ]

MODE_TO_OPERATION = { 'd' => '. ', 't' => ' d',
                      'h' => '_ ', 'g' => ' r',
                      'x' => '# ', 's' => ' s',
                      'j' => 'j ', 'e' => ' e',
                      'a' => ' A', 'q' => ' a',
                      'w' => ' W',
                      'f' => ' F',
                      'i' => 'i ',
                      'u' => 'u ',
                      'r' => 'r ',
                      'v' => 'v ',
}

PROTECT_MODE = { 'd' => [ '#', '@' ], 'h' => [ '.', '#', '@' ] }