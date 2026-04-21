% Wumpus World Agent - SWI-Prolog
% Author: Nguyen Le Gia Bao
% Description: Simulate a 4x4 Wumpus World and a simple reasoning agent.
% Usage: ?- [wumpus]. then ?- demo. or ?- start.

:- dynamic(agent_position/3).
:- dynamic(visited/2).
:- dynamic(wumpus_at/2).
:- dynamic(pit_at/2).
:- dynamic(gold_at/2).
:- dynamic(wumpus_alive/0).
:- dynamic(has_arrow/0).
:- dynamic(has_gold/0).
:- dynamic(bump_flag/0).
:- dynamic(scream_flag/0).
:- dynamic(possible_wumpus/2).
:- dynamic(possible_pit/2).
:- dynamic(known_safe/2).

% Grid bounds
max_x(4). max_y(4).

% Directions: east, north, west, south
left_of(east,north). left_of(north,west). left_of(west,south). left_of(south,east).
right_of(A,B):- left_of(B,A).

% move_delta(Direction,DX,DY)
move_delta(east, 1, 0).
move_delta(west,-1, 0).
move_delta(north,0, 1).
move_delta(south,0,-1).

% neighbor cells orthogonally adjacent
neighbor(X,Y,X2,Y2):- X2 is X+1, Y2 is Y, within(X2,Y2).
neighbor(X,Y,X2,Y2):- X2 is X-1, Y2 is Y, within(X2,Y2).
neighbor(X,Y,X2,Y2):- X2 is X, Y2 is Y+1, within(X2,Y2).
neighbor(X,Y,X2,Y2):- X2 is X, Y2 is Y-1, within(X2,Y2).

within(X,Y):- integer(X), integer(Y), X>=1, Y>=1, max_x(MX), max_y(MY), X =< MX, Y =< MY.

% ----------------------
% Environment initializer
% ----------------------
% init_map/0: mẫu map mặc định (có thể sửa các tọa độ)
init_map :-
    retractall(agent_position(_,_,_)), retractall(visited(_,_)),
    retractall(wumpus_at(_,_)), retractall(pit_at(_,_)), retractall(gold_at(_,_)),
    retractall(wumpus_alive), retractall(has_arrow), retractall(has_gold),
    retractall(bump_flag), retractall(scream_flag),
    retractall(possible_wumpus(_, _)), retractall(possible_pit(_, _)), retractall(known_safe(_, _)),
    % Example fixed placement (you can change these coordinates):
    assertz(wumpus_at(3,1)), assertz(wumpus_alive),
    assertz(pit_at(3,3)), assertz(pit_at(1,3)),
    assertz(gold_at(2,3)),
    % initial agent state
    assertz(agent_position(1,1,east)), assertz(visited(1,1)),
    assertz(has_arrow),
    format('Map initialized. Wumpus at (3,1) [hidden], pits at (3,3),(1,3), gold at (2,3).~n').

% random_map/0: đặt ngẫu nhiên Wumpus, một vài pits và gold (không ở 1,1)
random_map :-
        retractall(wumpus_at(_,_)), retractall(pit_at(_,_)), retractall(gold_at(_,_)),
        % choose random positions in 1..4 except (1,1)
        repeat,
            random_between(1,4,WX), random_between(1,4,WY),
            (WX =\= 1 ; WY =\= 1),
            !,
        assertz(wumpus_at(WX,WY)), assertz(wumpus_alive),
        % place 2 pits randomly
        place_random_pits(2),
        % place gold
        repeat,
            random_between(1,4,GX), random_between(1,4,GY),
            (GX =\= 1 ; GY =\= 1),
            \+ (GX=WX, GY=WY),
            !,
        assertz(gold_at(GX,GY)),
        retractall(agent_position(_,_,_)), retractall(visited(_,_)),
        assertz(agent_position(1,1,east)), assertz(visited(1,1)), assertz(has_arrow),
        format('Random map initialized.~n').

place_random_pits(0) :- !.
place_random_pits(N) :-
        N > 0,
        repeat,
            random_between(1,4,PX), random_between(1,4,PY),
            (PX =\= 1 ; PY =\= 1),
            \+ wumpus_at(PX,PY), \+ gold_at(PX,PY), \+ pit_at(PX,PY),
            !,
        assertz(pit_at(PX,PY)),
        N1 is N-1,
        place_random_pits(N1).

% ----------------------
% Percepts computation
% ----------------------
% stench: if Wumpus in neighbor and alive
stench_at(X,Y) :- wumpus_alive, neighbor(X,Y,X2,Y2), wumpus_at(X2,Y2).
% breeze: if any pit in neighbor
breeze_at(X,Y) :- neighbor(X,Y,X2,Y2), pit_at(X2,Y2).
% glitter: if gold at (X,Y)
glitter_at(X,Y) :- gold_at(X,Y).
% bump and scream are flags set when actions occur (bump_flag/scream_flag)

% current_percepts(PerceptsList) - [Stench,Breeze,Glitter,Bump,Scream]
current_percepts([Stench,Breeze,Glitter,Bump,Scream]) :-
    agent_position(X,Y,_),
    (stench_at(X,Y) -> Stench = yes ; Stench = no),
    (breeze_at(X,Y) -> Breeze = yes ; Breeze = no),
    (glitter_at(X,Y) -> Glitter = yes ; Glitter = no),
    (bump_flag -> Bump = yes ; Bump = no),
    (scream_flag -> Scream = yes ; Scream = no).

% clear transient percept flags after agent reads them
clear_transients :- (retract(bump_flag) -> true ; true), (retract(scream_flag) -> true ; true).

% ----------------------
% Knowledge update rules (inference)
% ----------------------
% Update knowledge from percepts at current cell
update_knowledge :-
    agent_position(X,Y,_), current_percepts([Stench,Breeze,_,_,Scream]),
    % If scream observed, no longer alive
    (Scream == yes -> (retractall(wumpus_alive), format('Heard scream: Wumpus dead.~n')) ; true),
    % Stench present: neighbors maybe wumpus
    (Stench == yes -> findall([NX,NY], (neighbor(X,Y,NX,NY), \+ known_safe(NX,NY)), L), mark_possible_wumpus(L) ; % else neighbors safe from wumpus
        findall([NX,NY], neighbor(X,Y,NX,NY), NL), mark_neighbors_not_wumpus(NL)),
    % Breeze present: neighbors maybe pit
    (Breeze == yes -> findall([NX,NY], (neighbor(X,Y,NX,NY), \+ known_safe(NX,NY)), PL), mark_possible_pit(PL) ;
        findall([NX,NY], neighbor(X,Y,NX,NY), NL2), mark_neighbors_not_pit(NL2)),
    % If no stench and no breeze, mark neighbors safe
    (Stench == no, Breeze == no -> findall([NX,NY], neighbor(X,Y,NX,NY), Neis), mark_safe_list(Neis) ; true),
    clear_transients.

mark_possible_wumpus([]) :- !.
mark_possible_wumpus([[X,Y]|T]) :- (possible_wumpus(X,Y) -> true ; assertz(possible_wumpus(X,Y))), mark_possible_wumpus(T).
mark_possible_pit([]) :- !.
mark_possible_pit([[X,Y]|T]) :- (possible_pit(X,Y) -> true ; assertz(possible_pit(X,Y))), mark_possible_pit(T).

mark_neighbors_not_wumpus([]) :- !.
mark_neighbors_not_wumpus([[X,Y]|T]) :- (retractall(possible_wumpus(X,Y)), assert_safe_if_not_pit(X,Y)), mark_neighbors_not_wumpus(T).
mark_neighbors_not_pit([]) :- !.
mark_neighbors_not_pit([[X,Y]|T]) :- (retractall(possible_pit(X,Y)), assert_safe_if_not_wumpus(X,Y)), mark_neighbors_not_pit(T).

assert_safe_if_not_pit(X,Y) :- (possible_pit(X,Y) -> true ; assertz(known_safe(X,Y))).
assert_safe_if_not_wumpus(X,Y) :- (possible_wumpus(X,Y) -> true ; assertz(known_safe(X,Y))).

mark_safe_list([]) :- !.
mark_safe_list([[X,Y]|T]) :- (retractall(possible_pit(X,Y)), retractall(possible_wumpus(X,Y)), (known_safe(X,Y) -> true ; assertz(known_safe(X,Y)))), mark_safe_list(T).

% Inference queries
% is_safe(X,Y): no possible pit and no possible wumpus and within grid
is_safe(X,Y) :- within(X,Y), \+ possible_pit(X,Y), \+ possible_wumpus(X,Y), (known_safe(X,Y) ; visited(X,Y)).

% possible_wumpus/2 and possible_pit/2 are dynamic facts asserted during update_knowledge

% ----------------------
% Actions and state updates
% ----------------------
% move_forward: attempt move in facing direction
move_forward :-
    retractall(bump_flag), agent_position(X,Y,Dir), move_delta(Dir,DX,DY), NX is X+DX, NY is Y+DY,
    (within(NX,NY) -> (
        retract(agent_position(X,Y,Dir)), assertz(agent_position(NX,NY,Dir)),
        (visited(NX,NY) -> true ; assertz(visited(NX,NY))),
        format('Action: moved to (~w,~w) facing ~w~n',[NX,NY,Dir]),
        % Check for death by pit or wumpus
        (pit_at(NX,NY) -> format('Fell into a pit at (~w,~w). Agent died.~n',[NX,NY]), fail ; true),
        (wumpus_alive, wumpus_at(NX,NY) -> format('Eaten by Wumpus at (~w,~w). Agent died.~n',[NX,NY]), fail ; true)
    ) ; (
        assertz(bump_flag), format('Action: bumped into wall at (~w,~w) when facing ~w~n',[X,Y,Dir])
    ) ).

turn_left :- agent_position(X,Y,Dir), left_of(Dir,New), retract(agent_position(X,Y,Dir)), assertz(agent_position(X,Y,New)), format('Action: turn_left -> now facing ~w~n',[New]).
turn_right :- agent_position(X,Y,Dir), right_of(Dir,New), retract(agent_position(X,Y,Dir)), assertz(agent_position(X,Y,New)), format('Action: turn_right -> now facing ~w~n',[New]).

grab :- agent_position(X,Y,_), (gold_at(X,Y) -> retract(gold_at(X,Y)), assertz(has_gold), format('Action: grab - picked gold at (~w,~w)~n',[X,Y]) ; format('Action: grab - no gold here.~n')).

shoot :- (has_arrow -> retractall(has_arrow), agent_position(X,Y,Dir), (shoot_hit(X,Y,Dir) -> (retractall(wumpus_at(_, _)), retractall(wumpus_alive), assertz(scream_flag), format('Action: shoot - hit Wumpus!~n')) ; format('Action: shoot - missed.~n')) ; format('No arrow to shoot.~n')).

% shoot_hit checks whether there's a wumpus somewhere ahead in straight line
shoot_hit(X,Y,Dir) :- move_delta(Dir,DX,DY), shoot_line(X,Y,DX,DY).
shoot_line(X,Y,DX,DY) :- NX is X+DX, NY is Y+DY, within(NX,NY), (wumpus_at(NX,NY) -> true ; shoot_line(NX,NY,DX,DY)).

climb :- agent_position(1,1,_), (has_gold -> format('Action: climb - exited with gold. Success!~n'), ! ; format('Action: climb - have no gold. You can still climb but mission fails to collect gold.~n')).
climb :- format('Action: climb - can only climb at (1,1).~n'), fail.

% ----------------------
% Utility: face a neighbor cell before moving
% ----------------------
face_to(X,Y) :- agent_position(A,B,Dir), DX is X-A, DY is Y-B, target_dir(DX,DY,Target), rotate_to(Target).

target_dir(1,0,east).
target_dir(-1,0,west).
target_dir(0,1,north).
target_dir(0,-1,south).

rotate_to(Target) :- agent_position(_,_,Target), !.
rotate_to(Target) :- agent_position(_,_,Dir), left_of(Dir,Left), (Left==Target -> turn_left ; (right_of(Dir,Right), Right==Target -> turn_right ; turn_right)).

% move_to_cell(X,Y): orient then move
move_to_cell(X,Y) :- face_to(X,Y), move_forward.

% ----------------------
% Agent decision logic (simple exploration + backtrack)
% ----------------------
% choose_action(Action) returns an action atom to perform next
choose_action(Action) :-
    agent_position(X,Y,_), current_percepts([Stench,Breeze,Glitter,Bump,Scream]),
    % Priority 1: pick up gold
    (Glitter==yes -> Action = grab ;
    % Priority 2: if have gold and at start, climb
    (has_gold, X==1, Y==1 -> Action = climb ;
    % Priority 3: if glitter absent, explore safe unvisited neighbor
    (find_safe_unvisited_neighbor(X,Y,NX,NY) -> Action = move(NX,NY) ;
    % Priority 4: if stench and have arrow, try shooting
    (Stench==yes, has_arrow -> Action = shoot ;
    % Priority 5: backtrack to some safe visited neighbor
    (find_safe_visited_neighbor(X,Y,NX2,NY2) -> Action = move(NX2,NY2) ;
    % Priority 6: if nothing left, if has_gold go home else give up and climb if at 1,1
    (has_gold -> Action = go_home ; (X==1, Y==1 -> Action = climb ; Action = give_up))))))).

find_safe_unvisited_neighbor(X,Y,NX,NY) :- neighbor(X,Y,NX,NY), \+ visited(NX,NY), is_safe(NX,NY), !.
find_safe_visited_neighbor(X,Y,NX,NY) :- neighbor(X,Y,NX,NY), visited(NX,NY), is_safe(NX,NY), !.

% go_home chooses a step that moves closer to (1,1) via safe visited cells
go_home_step(NX,NY) :- agent_position(X,Y,_), findall([AX,AY], (neighbor(X,Y,AX,AY), visited(AX,AY), is_safe(AX,AY)), L), sort_by_dist_to_start(L,[[NX,NY]|_]).

sort_by_dist_to_start(L,Sorted) :- map_list_to_pairs(dist_start,L,Pairs), keysort(Pairs,SP), pairs_values(SP,Sorted).
dist_start([AX,AY],D) :- D is abs(AX-1)+abs(AY-1).

% ----------------------
% Main loop step
% ----------------------
step :-
    % show percepts
    current_percepts(Per), format('Percepts: ~w~n',[Per]),
    % update knowledge
    update_knowledge,
    % choose action
    (choose_action(Action) -> true ; Action = give_up),
    (Action = grab -> grab, step_continue ;
     Action = climb -> (climb -> format('Finished.~n'), ! ; step_continue) ;
     Action = shoot -> shoot, step_continue ;
     Action = give_up -> format('No more safe moves. Agent gives up.~n'), ! ;
     Action = go_home -> (go_home_step(NX,NY) -> (format('Going home step to (~w,~w)~n',[NX,NY]), move_to_cell(NX,NY), step_continue) ; (format('Cannot find safe path home. Giving up.~n'), !)) ;
     Action = move(MX,MY) -> (format('Decided to move to (~w,~w)~n',[MX,MY]), move_to_cell(MX,MY), step_continue) ;
     format('Unknown action ~w~n',[Action]), step_continue).

step_continue :-
    % check termination conditions: gold & at (1,1) handled by climb above
    agent_position(X,Y,_), (has_gold, X==1, Y==1 -> format('Agent at (1,1) with gold. Call climb to exit.~n') ; true),
    % continue loop
    step.

% start: initialize and run loop (assumes init_map or random_map called beforehand)
start :-
    (\+ agent_position(_,_,_) -> init_map ; true),
    format('Starting agent loop...~n'),
    (catch(step,_,(format('Agent terminated (died or finished).~n'), !))).

% demo: convenience predicate to init sample map and run
demo :- init_map, start.

% ----------------------
% Helper: show knowledge
% ----------------------
show_knowledge :-
    format('Agent position: '), (agent_position(X,Y,D), format('(~w,~w) facing ~w~n',[X,Y,D]) ; format('unknown~n')),
    format('Visited: '), findall([A,B], visited(A,B), V), format('~w~n',[V]),
    format('Known safe: '), findall([A,B], known_safe(A,B), S), format('~w~n',[S]),
    format('Possible pits: '), findall([A,B], possible_pit(A,B), PP), format('~w~n',[PP]),
    format('Possible wumpus: '), findall([A,B], possible_wumpus(A,B), PW), format('~w~n',[PW]),
    format('Has arrow: '), (has_arrow -> format('yes~n') ; format('no~n')),
    format('Has gold: '), (has_gold -> format('yes~n') ; format('no~n')).

% ----------------------
% Run examples / instructions (in comments)
% ----------------------
% Hướng dẫn chạy:
% 1) Mở SWI-Prolog, tải file:
%    ?- ["d:/TaiLieu/Se_3_HK2/Nhập môn A_I/Projects/BT/EX 6.1 Ngôn ngữ Prolog/wumpus"].
%    (hoặc sao chép file vào folder làm việc và dùng ?- [wumpus].)
% 2) Khởi tạo bản đồ mẫu và bắt đầu agent:
%    ?- demo.
%   hoặc khởi tạo bản đồ ngẫu nhiên:
%    ?- random_map, start.
% 3) Để xem kiến thức hiện tại (sau khi chạy 1 bước hoặc nhiều bước), gọi:
%    ?- show_knowledge.

% Ghi chú quan trọng:
% - Đây là một agent đơn giản, dùng heuristic cục bộ: ưu tiên ô an toàn chưa thăm.
% - Luật suy diễn: possible_wumpus(X,Y) và possible_pit(X,Y) được đánh dấu dựa trên stench/breeze.
% - is_safe/2 trả true khi không còn đánh dấu khả năng wumpus/pit.
% - Khi agent nghe "scream" (khi bắn trúng), Wumpus được gỡ bỏ khỏi bản đồ.
% - Chiến lược di chuyển có thể bị giới hạn và không đảm bảo tìm vàng trong mọi trường hợp.

% Kết thúc file
