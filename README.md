# Wumpus World (SWI-Prolog)

Mô tả
- Triển khai môi trường Wumpus World (lưới 4x4) và một Agent suy luận viết bằng SWI-Prolog.

Author: Nguyen Le Gia Bao

Hướng dẫn chạy nhanh
1) Mở SWI-Prolog và nạp file:
   ?- consult('wumpus.pl').
   hoặc nếu file ở thư mục khác: ?- consult('đường/dẫn/đến/wumpus.pl').
2) Chạy bản demo mẫu:
   ?- demo.
   Hoặc khởi tạo bản đồ ngẫu nhiên rồi chạy:
   ?- random_map, start.
3) Để quan sát kiến thức Agent học được:
   ?- show_knowledge.

Ghi chú
- Mã do `Nguyen Le Gia Bao` viết; mục tiêu là minh họa biểu diễn tri thức và suy luận đơn giản trong Prolog.
- Commit và README không chứa bất kỳ cụm từ nào về "add làm cùng với agent".
