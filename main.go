package main

import (
	"encoding/json"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"log"
	"net/http"
)

type article struct {
	Body   string `json:"body"`
	Title  string `json:"title"`
	Author string `json:"author"`
}

var errorLogger = log.New(os.Stderr, "ERROR ", log.Llongfile)

func show(req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	article, err := getItem("N3WART1CL3")
	if err != nil {
		return serverError(err)
	}
	if article == nil {
		return clientError(http.StatusBadRequest)
	}

	art, err := json.Marshal(article)
	if err != nil {
		return serverError(err)
	}

	return events.APIGatewayProxyResponse{StatusCode: http.StatusOK, Body: string(article)}, nil
}

func serverError(err error) (events.APIGatewayProxyResponse, error) {
	errorLogger.Println(err.Error())

	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusInternalServerError,
		Body:       http.StatusText(http.StatusInternalServerError),
	}, nil
}

func clientError(status int) (events.APIGatewayProxyResponse, error) {
	return events.APIGatewayProxyResponse{
		StatusCode: status,
		Body:       http.StatusText(status),
	}, nil
}

func main() {
	lambda.Start(show)
}
