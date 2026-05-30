package main

import (
	"fmt"
	"math/rand"
	"net/http"

	"github.com/gin-gonic/gin"
)

var greetings = []string{
	"Hello, World!",
	"Howdy, World!",
	"Bonjour, World!",
}

func main() {
	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	r.GET("/hello", func(c *gin.Context) {
		msg := greetings[rand.Intn(len(greetings))]
		fmt.Println(msg)
		c.JSON(http.StatusOK, gin.H{"message": msg})
	})

	r.Run(":3000")
}
