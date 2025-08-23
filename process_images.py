import cv2
from rdp import rdp
import json
import pathlib
from typing import Any, TypeAlias
from numpy import ndarray, dtype, integer, floating

Image: TypeAlias = ndarray[Any, dtype[integer[Any] | floating[Any]]]
Point: TypeAlias = tuple[float, float]

WIN_NAME = 'Image Preprocessor'
HORSE_RADIUS = 16

MOUSE_COORDINATES: Point = (0, 0)
MOUSE_CLICKED = False

def with_text(img: Image, s: str) -> Image:
    (text_width, text_height), b = cv2.getTextSize(s, cv2.FONT_HERSHEY_COMPLEX, 0.5, 1)

    height, _, _ = img.shape
    padding = 10

    cv2.rectangle(img, (0, height - text_height - 2 * padding), (text_width + 2 * padding, height), (0, 0, 0), -1)
    cv2.putText(img, s, (padding, height - padding), cv2.FONT_HERSHEY_COMPLEX, 0.5, (255, 255, 255), 1)

    return img

def parse_contours(img: Image) -> list[list[Point]]:
    img_thresh = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    contours, hierarchy = cv2.findContours(img_thresh, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_TC89_L1)

    # dirty, but it gets us json-ifiable
    eps = 10
    while True:
        img_copy = img.copy()
        simplified_contours = list(map(lambda c: rdp(c, epsilon=eps), contours))
        py_contours = [
            [{'x': float(x[0][0]), 'y': float(x[0][1])} for x in c]
            for c in simplified_contours]

        total_pts = sum(len(c) for c in py_contours)

        cv2.drawContours(img_copy, simplified_contours, -1, (255, 0, 0), 2)

        cv2.imshow(WIN_NAME, with_text(img_copy, f"eps={eps}. {total_pts} pts. - for fewer pts, + for more pts, <CR> to submit"))
        key = cv2.waitKey(0)
        if chr(key) in "-_":
            eps += 1
        if chr(key) in "=+":
            eps -= 1
        if key == 13:
            return py_contours

    # if args.n:
    #     output = path.with_suffix(".json")
    #
    #     print(f"Writing {output}...")
    #     with open(output, 'w') as of:
    #         json.dump(py_contours, of)

def parse_spawn(img: Image) -> Any:
    global MOUSE_CLICKED, MOUSE_COORDINATES
    MOUSE_CLICKED = False

    def mouse_callback(evt: int, x: int, y: int, *_: Any) -> None:
        global MOUSE_CLICKED, MOUSE_COORDINATES
        if evt == cv2.EVENT_LBUTTONDOWN:
            MOUSE_COORDINATES = (x, y)
            MOUSE_CLICKED = True

    cv2.setMouseCallback(WIN_NAME, mouse_callback)

    result: list[Point] = []
    goal: Point | None = None
    gate: Point | None = None

    gw, gh = 25, 100
    def draw_image() -> None:
        if len(result) < 8:
            s = "Click center of spawn points"
        elif goal is None:
            s = "Click center of goal"
        else:
            s = "Click center of gate"

        img_show = with_text(img.copy(), s)

        for pt in result:
            cv2.circle(img_show, (int(pt[0]), int(pt[1])), HORSE_RADIUS, (0, 255, 0), -1)
        if goal:
            cv2.circle(img_show, (int(goal[0]), int(goal[1])), HORSE_RADIUS, (0, 0, 255), -1)
        if gate:
            r1 = (int(gate[0] - gw), int(gate[1] - gh))
            r2 = (int(gate[0] + gw), int(gate[1] + gh))

            cv2.rectangle(img_show, r1, r2, (0, 0, 255), -1)
        cv2.imshow(WIN_NAME, img_show)

    draw_image()
    while len(result) < 8:

        MOUSE_CLICKED = False
        while not MOUSE_CLICKED:
            cv2.waitKey(1)

        for pt in result:
            dx = pt[0] - MOUSE_COORDINATES[0]
            dy = pt[1] - MOUSE_COORDINATES[1]
            if dx*dx+dy*dy <= (HORSE_RADIUS*3) ** 2:
                break
        else:
            result.append(MOUSE_COORDINATES)
            draw_image()

    MOUSE_CLICKED = False
    while not MOUSE_CLICKED:
        cv2.waitKey(1)
    goal = MOUSE_COORDINATES
    draw_image()

    MOUSE_CLICKED = False
    while not MOUSE_CLICKED:
        cv2.waitKey(1)
    gate = MOUSE_COORDINATES
    draw_image()

    cv2.waitKey(1000)


    return {
        "spawns": [{"x": p[0], "y": p[1]} for p in result],
        "goal": {"x": goal[0], "y": goal[1]},
        "gate": {"x": gate[0] - gw, "y": gate[1] - gh}
    }


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(
        prog='Image Preprocessor',
    )
    parser.add_argument('directory', type=pathlib.Path)
    parser.add_argument('-n', action='store_false')
    args = parser.parse_args()

    directory: pathlib.Path = args.directory
    if not directory.is_dir():
        raise ValueError(f"Specified path '{directory}' is not a directory")

    image_paths = list(directory.glob('*.png')) + list(directory.glob('*.jpg'))

    cv2.namedWindow(WIN_NAME)
    for path in image_paths:
        img = cv2.imread(str(path.resolve()))
        assert(img is not None)
        contours = parse_contours(img)
        pts = parse_spawn(img)

        if args.n:
            output = path.with_suffix(".json")
            obj = {**pts, "walls": contours}

            print(f"Writing {output}...")
            with open(output, 'w') as of:
                json.dump(obj, of)

    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()

