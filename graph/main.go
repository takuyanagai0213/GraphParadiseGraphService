package main

import (
	"context"
	"fmt"
	"html/template"
	"log"
	"net/http"

	// "github.com/jinzhu/gorm"
	"graph_paradise/grpc/user"
)

func main() {
	// dir, _ := os.Getwd()

	// http.HandleFunc("/graph", graph)
	// http.HandleFunc("/getRooms", api.GetRooms)
	// http.HandleFunc("/getAreas", api.GetAreas)
	// http.HandleFunc("/getDataTypeList", api.GetDataTypeList)
	// http.HandleFunc("/getDates", api.GetDates)
	// http.HandleFunc("/getData1", api.GetData1)
	// http.HandleFunc("/GetDataForTable", api.GetDataForTable)
	// http.HandleFunc("/getDataForDaily", api.GetDataForDaily)
	// http.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir(dir+"/static/"))))
	// port
	// http.ListenAndServe(":80", nil)
	conn, err := grpc.Dial("127.0.0.1:90", grpc.WithInsecure())
	if err != nil {
		log.Fatal("client connection error:", err)
	}
	defer conn.Close()
	client := user.NewCatClient(conn)
	message := &user.GetName{User: "takuya"}
	res, err := client.GetMyCat(context.TODO(), message)
	fmt.Printf("result:%#v \n", res)
	fmt.Printf("error::%#v \n", err)
}

func graph(w http.ResponseWriter, r *http.Request) {
	t, err := template.ParseFiles("index.html")
	if err != nil {
		panic(err.Error())
	}
	if err := t.Execute(w, nil); err != nil {
		panic(err.Error())
	}
}
