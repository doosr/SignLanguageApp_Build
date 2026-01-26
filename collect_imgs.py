import os
import cv2


class DataCollector:
    def __init__(self, data_dir='./Data', number_of_classes=27, dataset_size=100):
        self.data_dir = data_dir
        self.number_of_classes = number_of_classes
        self.dataset_size = dataset_size

        if not os.path.exists(self.data_dir):
            os.makedirs(self.data_dir)

        # Robust camera search to find working index
        valid_index = 0
        valid_backend = cv2.CAP_ANY
        
        found = False
        for backend_name, backend_id in [('Default', cv2.CAP_ANY), ('DSHOW', cv2.CAP_DSHOW)]:
            for index in range(2): 
                print(f"Checking camera index {index} with {backend_name}...")
                temp_cap = cv2.VideoCapture(index, backend_id)
                if temp_cap.isOpened():
                    ret, _ = temp_cap.read()
                    if ret:
                        print(f"Found working camera: Index {index}, Backend {backend_name}")
                        valid_index = index
                        valid_backend = backend_id
                        found = True
                        temp_cap.release()
                        break
                    temp_cap.release()
            if found:
                break
        
        if not found:
            print("WARNING: No working camera found during check. Defaulting to 0.")
        
        # Open camera with the validated settings
        print(f"Opening camera {valid_index} with backend {valid_backend}")
        self.cap = cv2.VideoCapture(valid_index, valid_backend)

    def collect_data(self):
        for j in range(self.number_of_classes):
            class_dir = os.path.join(self.data_dir, str(j))
            if not os.path.exists(class_dir):
                os.makedirs(class_dir)

            print('Collecting data for class {}'.format(j))

            self._wait_for_key_press()

            self._collect_class_data(j)

    def _wait_for_key_press(self):
        done = False
        while not done:
            ret, frame = self.cap.read()
            if not ret or frame is None:
                print("ERROR: Cannot read frame from camera. Please check your camera connection.")
                raise RuntimeError("Camera not working properly")
            cv2.putText(frame, 'Ready? Press "R" ! :)', (100, 50), cv2.FONT_HERSHEY_SIMPLEX, 1.3, (0, 255, 0), 3,
                        cv2.LINE_AA)
            cv2.imshow('frame', frame)
            key = cv2.waitKey(1)
            if key == ord('r') or key == ord('R'):
                done = True
            elif key == ord('q'):
                print("Quitting collection...")
                self.cap.release()
                cv2.destroyAllWindows()
                exit()

    def _collect_class_data(self, class_index):
        counter = 0
        while counter < self.dataset_size:
            ret, frame = self.cap.read()
            if not ret or frame is None:
                print(f"ERROR: Cannot read frame {counter}. Skipping...")
                continue
            cv2.imshow('frame', frame)
            cv2.waitKey(1)
            cv2.imwrite(os.path.join(self.data_dir, str(class_index), '{}.jpg'.format(counter)), frame)
            counter += 1

    def release(self):
        self.cap.release()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    collector = DataCollector()
    collector.collect_data()
    collector.release()
