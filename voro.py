# USE VORONOIS TO FIND EXTREMITIES THAT CAN BE REACHED
# CHANGE ACCORDINGLY
import requests

class SmartBike:
    def __init__(self):
        self.url = "light-bikes.inseng.net/games"
        self.game_id = 0
        self.voro = 0

    def hunt(self):
        print("Looking")

    def calculate_voronoi(self):
        print("Calculating")

    def request(self):
        r = requests.get(url = self.url) 

        # extracting data in json format 
        data = r.json() 
        print(data)
        print("Requesting")

def main():
    sm = SmartBike()
    sm.request()

    # While not dead, keep polling


if __name__ == "__main__":
    main()

