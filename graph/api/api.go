package api

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"strconv"
	// "github.com/jinzhu/gorm"
)

type Room struct {
	room_no   string
	room_name string
}

func GetDataTypeList(w http.ResponseWriter, r *http.Request) {
	var data_type_list []interface{}

	var buf map[string]interface{}
	buf = map[string]interface{}{}
	buf["data_type_no"] = "1"
	buf["data_type_name"] = "温度"
	data_type_list = append(data_type_list, buf)
	buf = map[string]interface{}{}
	buf["data_type_no"] = "2"
	buf["data_type_name"] = "湿度"
	data_type_list = append(data_type_list, buf)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data_type_list)
}
func GetAreas(w http.ResponseWriter, r *http.Request) {
	var area_info []interface{}

	var buf map[string]interface{}
	for i := 1; i < 5; i++ {
		buf = map[string]interface{}{}
		buf["area_name"] = "エリア" + strconv.Itoa(i)
		buf["area_no"] = strconv.Itoa(i)
		area_info = append(area_info, buf)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(area_info)
}
func GetRooms(w http.ResponseWriter, r *http.Request) {
	var data []interface{}

	var buf map[string]interface{}
	for i := 1; i < 11; i++ {
		buf = map[string]interface{}{}
		buf["room_name"] = "部屋" + strconv.Itoa(i)
		buf["room_no"] = strconv.Itoa(i)
		data = append(data, buf)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}
func GetDates(w http.ResponseWriter, r *http.Request) {
	var data = make([]int, 30)
	for i := 0; i < 30; i++ {
		data[i] = rand.Intn(100)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}
func GetData1(w http.ResponseWriter, r *http.Request) {
	data := createDummyData()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}
func GetDataForDaily(w http.ResponseWriter, r *http.Request) {
	var temp = make([]int, 30)

	for i := 0; i < 30; i++ {
		temp[i] = rand.Intn(100)
	}
	var co2 = make([]int, 30)

	for i := 0; i < 30; i++ {
		co2[i] = rand.Intn(100)
	}
	fmt.Println(temp)
	var data []interface{}
	var buf map[string]interface{}
	for i := 1; i < 11; i++ {
		buf = map[string]interface{}{}
		buf["room_no"] = strconv.Itoa(i)
		buf["temp"] = temp
		buf["co2"] = co2
		data = append(data, buf)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}
func createDummyData() []int {
	var data = make([]int, 10)
	for i := 0; i < 10; i++ {
		data[i] = rand.Intn(100)
	}

	return data
}
func GetDataForTable(w http.ResponseWriter, r *http.Request) {
	data := createDummyData()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}
