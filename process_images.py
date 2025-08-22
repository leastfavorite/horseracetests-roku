import cv2
from rdp import rdp
import json

if __name__ == "__main__":
    import argparse
    import pathlib

    parser = argparse.ArgumentParser(
        prog='Image Preprocessor',
    )
    parser.add_argument('directory', type=pathlib.Path)
    parser.add_argument('-s', action='store_true')
    parser.add_argument('-n', action='store_false')
    args = parser.parse_args()

    directory: pathlib.Path = args.directory
    if not directory.is_dir():
        raise ValueError(f"Specified path '{directory}' is not a directory")

    image_paths = list(directory.glob('*.png')) + list(directory.glob('*.jpg'))

    for path in image_paths:
        img = cv2.imread(str(path.resolve()))
        img_thresh = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        contours, hierarchy = cv2.findContours(img_thresh, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_TC89_L1)
        simplified_contours = list(map(lambda c: rdp(c, epsilon=5), contours))

        # dirty, but it gets us json-ifiable
        py_contours = [
            [{'x': float(x[0][0]), 'y': float(x[0][1])} for x in c]
            for c in simplified_contours]

        if args.s:
            cv2.drawContours(img, simplified_contours, -1, (255, 0, 0), 2)

            cv2.imshow("Image Display", img)
            cv2.waitKey(0)
            cv2.destroyAllWindows()

        if args.n:
            output = path.with_suffix(".json")

            print(f"Writing {output}...")
            with open(output, 'w') as of:
                json.dump(py_contours, of)


