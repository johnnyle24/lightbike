#VOROHUNTER
require 'net/http'
require 'json'
require 'HTTParty'

require 'pry'

def create_game(bot, size, players, difficulty)
  res = HTTParty.post("http://light-bikes.inseng.net/games?addServerBot=#{bot}&boardSize=#{size}&numPlayers=#{players}&serverBotDifficulty=#{difficulty}",
  {
    :body => {
    }.to_json,
    :headers => { 'Content-Type' => 'application/json'}
  })
  JSON[res.body]["id"]
end

def get_games
  res = HTTParty.get("http://light-bikes.inseng.net/games",
    {
    :body => {
    }.to_json,
    :headers => {
      'Content-Type' => 'application/json',
      'X-Token' => token
    }
  })
  JSON[res.body]
end

def join_game(id)
  res = HTTParty.post("http://light-bikes.inseng.net/games/#{id}/join?name=Kirby",
  {
    :body => {
  }.to_json,
    :headers => { 'Content-Type' => 'application/json'}
  })
end

def play_move(gameId, playerId, x, y)
  res = HTTParty.post("http://light-bikes.inseng.net/games/#{gameId}/move?playerId=#{playerId}&x=#{x}&y=#{y}",
    {
    :body => {
    }.to_json,
    :headers => { 'Content-Type' => 'application/json' }
  })
  res
end

def create_voronoi(board, px, py, other_players)
  edges = []

  edge_diagram = Array.new(board[0].length) { Array.new(board[0].length) }

  count = 0
  board.each_with_index do |row, y|
    row.each_with_index do |cell, x|
      unless cell
        # calculate min manhattan distance of cell from others players
        min_distance = closest(x, y, other_players)["min"]

        # calculate manhattan distance of cell from player
        player_man = manhattan(x, y, px, py)

        difference = player_man - min_distance
        # subtract min other from player distance and if it equals -1, add to list
        if difference == -1 or difference == 0
          count += 1
          edges << {"x"=>x, "y"=>y}
          edge_diagram[x][y] = 1
        else
          edge_diagram[x][y] = 0
        end
      end
    end
  end

  edges
end

def farthest(x, y, others)
  if others.length == 0
    return {"closest" => {"x"=>x, "y"=>y}, "min"=>0}
  end

  min_distance = manhattan(x, y, others[0]["x"], others[0]["y"])
  closest = others[0]

  others.each do |other|
    distance = manhattan(x, y, other["x"], other["y"])
    if distance > min_distance
      min_distance = distance
      closest = other
    end
  end

  {"closest" => closest, "min"=>min_distance}
end

def closest(x, y, others)
  if others.length == 0
    return {"closest" => {"x"=>x, "y"=>y}, "min"=>0}
  end

  min_distance = manhattan(x, y, others[0]["x"], others[0]["y"])
  closest = others[0]

  others.each do |other|
    distance = manhattan(x, y, other["x"], other["y"])
    if distance < min_distance
      min_distance = distance
      closest = other
    end
  end

  {"closest" => closest, "min"=>min_distance}
end

def manhattan(x1, y1, x2, y2)
  (x1 - x2).abs + (y1 - y2).abs
end

def direction(board, player, target, other_players)
  up = {"x"=>player["x"]-1, "y"=>player["y"]}
  down = {"x"=>player["x"]+1, "y"=>player["y"]}
  left = {"x"=>player["x"], "y"=>player["y"]-1}
  right = {"x"=>player["x"], "y"=>player["y"]+1}

  directions = []

  directions << up if is_valid(board, up)
  directions << down if is_valid(board, down)
  directions << left if is_valid(board, left)
  directions << right if is_valid(board, right)

  if directions.length == 2
    first_area = find_area(board, directions[0])
    second_area = find_area(board, directions[1])

    if first_area > second_area
      return directions[0]
    else
      return directions[1]
    end
  end

  if player["x"].to_i < target["x"].to_i
    if is_valid(board, up) and is_possible(board, up, target) and check_viable(board, up, other_players, target)
      return up
    else
      return valid_other_direction(directions, 0, board, target)
    end
  end

  if player["x"].to_i > target["x"].to_i
    if is_valid(board, down) and is_possible(board, down, target) and check_viable(board, down, other_players, target)
      return down
    else
      return valid_other_direction(directions, 1, board, target)
    end
  end

  if player["y"].to_i < target["y"].to_i
    if is_valid(board, left) and is_possible(board, left, target) and check_viable(board, left, other_players, target)
      return left
    else
      return valid_other_direction(directions, 2, board, target)
    end
  end

  if player["y"].to_i > target["y"].to_i
    if is_valid(board, right) and is_possible(board, right, target) and check_viable(board, right, other_players, target)
      return right
    else
      return valid_other_direction(directions, 3, board, target)
    end
  end

  valid_other_direction(directions, 3, board, target)
end

def valid_other_direction(directions, not_valid, board, target)
  direction = directions[0]

  directions.each_with_index do |dir, index|
    if is_valid(board, dir) and is_possible(board, dir, target)
      direction = dir
    end
  end

  direction
end

def is_valid(board, coord)
  valid_x = (coord["x"].to_i < board.length and coord["x"].to_i > -1)
  valid_y = (coord["y"].to_i < board[0].length and coord["y"].to_i > -1)
  if valid_x and valid_y
    return !!!board[coord["x"]][coord["y"]]
  end

  false
end

def get_other_players(game_details)
  current_player = JSON[game_details.body][0]["current_player"]
  pcolor = current_player["color"]

  players = JSON[game_details.body][0]["players"]

  other_players = []

  players.each do |player|
    if player["color"] != pcolor
      other_players << player
    end
  end

  other_players
end

def should_update(board, player)
  up = {"x"=>player["x"]-1, "y"=>player["y"]}
  down = {"x"=>player["x"]+1, "y"=>player["y"]}
  left = {"x"=>player["x"], "y"=>player["y"]-1}
  right = {"x"=>player["x"], "y"=>player["y"]+1}

  valid_dir = []

  valid_dir << up if is_valid(board, up)
  valid_dir << down if is_valid(board, down)
  valid_dir << left if is_valid(board, left)
  valid_dir << right if is_valid(board, right)

  if valid_dir.length == 0
    return 0
  end

  current_area = find_area(board, valid_dir[0])

  different_area = false
  valid_dir.each do |dir|
    area = find_area(board, dir)
    if area != current_area
      different_area = true
    end
  end

  different_area
end

def is_possible(board, current, target)
  visited = Hash.new

  stack = []
  stack << current

  possible = false
  while stack.length != 0
    coord = stack.pop
    if coord["x"].to_i == target["x"].to_i and coord["y"].to_i == target["y"].to_i
      possible = true
      break
    end

    up = {"x"=>coord["x"]-1, "y"=>coord["y"]}
    down = {"x"=>coord["x"]+1, "y"=>coord["y"]}
    left = {"x"=>coord["x"], "y"=>coord["y"]-1}
    right = {"x"=>coord["x"], "y"=>coord["y"]+1}

    valid_dir = []

    valid_dir << up if is_valid(board, up)
    valid_dir << down if is_valid(board, down)
    valid_dir << left if is_valid(board, left)
    valid_dir << right if is_valid(board,right)

    valid_dir.each do |dir|
      visited_key = 'x' + dir["x"].to_s + 'y' + dir["y"].to_s
      unless visited.key?(visited_key)
        visited[visited_key] = 1
        stack << {"x"=>dir["x"], "y"=>dir["y"]}
      end
    end
  end

  possible
end

def check_viable(board, target, other_players, edge)
  # see if another player is one square away from target and that square is the only option
  up = {"x"=>target["x"]-1, "y"=>target["y"]}
  down = {"x"=>target["x"]+1, "y"=>target["y"]}
  left = {"x"=>target["x"], "y"=>target["y"]-1}
  right = {"x"=>target["x"], "y"=>target["y"]+1}

  valid_dir = []

  valid_dir << up if is_valid(board, up)
  valid_dir << down if is_valid(board, down)
  valid_dir << left if is_valid(board, left)
  valid_dir << right if is_valid(board, right)

  if valid_dir.length > 2
    return true
  elsif valid_dir.length == 2
    score = 0

    valid_dir.each do |dir|
      if is_possible(board, dir, edge)
        within_one_square = false

        other_players.each do |other|
          if manhattan(dir["x"], dir["y"], other["x"], other["y"]) == 1
            within_one_square = true
          end
        end

        unless within_one_square
          score += 1
        end
      end
    end

    if score > 0
      return true
    end

    return false
  elsif valid_dir.length == 1
    within_one_square = false

    other_players.each do |other|
      if manhattan(valid_dir[0]["x"], valid_dir[0]["y"], other["x"], other["y"]) == 1
        within_one_square = true
      end
    end

    return within_one_square
  end

  false
end

def find_area(board, current)
  visited = Hash.new

  stack = []
  stack << current

  area = 0

  while stack.length != 0
    coord = stack.pop
    area += 1

    up = {"x"=>coord["x"]-1, "y"=>coord["y"]}
    down = {"x"=>coord["x"]+1, "y"=>coord["y"]}
    left = {"x"=>coord["x"], "y"=>coord["y"]-1}
    right = {"x"=>coord["x"], "y"=>coord["y"]+1}

    valid_dir = []

    valid_dir << up if is_valid(board, up)
    valid_dir << down if is_valid(board, down)
    valid_dir << left if is_valid(board, left)
    valid_dir << right if is_valid(board,right)

    valid_dir.each do |dir|
      visited_key = 'x' + dir["x"].to_s + 'y' + dir["y"].to_s
      unless visited.key?(visited_key)
        visited[visited_key] = 1
        stack << {"x"=>dir["x"], "y"=>dir["y"]}
      end
    end
  end

  area
end

def game_loop
  bot = true
  size = 20
  players = 2
  difficulty = 4
  game_id = create_game(bot, size, players, difficulty)
  game_details = join_game(game_id)

  game_board = JSON[game_details.body][0]["board"]
  current_player = JSON[game_details.body][0]["current_player"]
  pid = current_player["id"]
  pcolor = current_player["color"]
  puts "Current Player: #{current_player}"

  gaming = true
  first_time = true

  while gaming
    game_board = JSON[game_details.body][0]["board"]
    current_player = JSON[game_details.body][0]["current_player"]

    px = current_player["x"]
    py = current_player["y"]

    voro_edges = create_voronoi(game_board, px, py, get_other_players(game_details))

    if first_time
      closest_edge = farthest(px, py, voro_edges)["closest"]
      first_time = false
    else
      closest_edge = closest(px, py, voro_edges)["closest"]
    end

    not_reached = true

    while not_reached
      game_board = JSON[game_details.body][0]["board"]
      current_player = JSON[game_details.body][0]["current_player"]
      px = current_player["x"]
      py = current_player["y"]

      direction = direction(game_board, current_player, closest_edge, get_other_players(game_details))

      puts current_player
      puts direction
      if direction == nil
        direction = {"x"=>px, "y"=>py}
      end

      if direction["x"] == closest_edge["x"] and direction["y"] == closest_edge["y"]
        not_reached = false
      end

      game_details = play_move(game_id, pid, direction["x"], direction["y"])

      if should_update(game_board, {"x"=>px, "y"=>py})
        not_reached = false
      end

      if JSON[game_details.body][0] == nil
        gaming = false
        break
      end

      status = !!JSON[game_details.body][0]["winner"]

      if status or JSON[game_details.body][0]["winner"]
        gaming = false
        break
      end
    end
  end
end

game_loop
