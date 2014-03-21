package main

import (
	"flag"
	"koding/messaging/rabbitmq"
	"koding/tools/config"
	"koding/tools/logger"
	followingfeed "socialapi/workers/followingfeed/lib"

	"github.com/streadway/amqp"
)

func startHandler() func(delivery amqp.Delivery) {
	log.Info("Worker Started to Consume")
	return func(delivery amqp.Delivery) {
		err := handler.HandleEvent(delivery.Type, delivery.Body)
		switch err {
		case nil:
			delivery.Ack(false)
		case followingfeed.HandlerNotFoundErr:
			log.Notice("unknown event type (%s) recieved, \n deleting message from RMQ", delivery.Type)
			delivery.Ack(false)
		default:
			// add proper error handling
			// instead of puttting message back to same queue, it is better
			// to put it to another maintenance queue/exchange
			log.Error("an error occured %s, \n putting message back to queue", err)
			// multiple false
			// reque true
			delivery.Nack(false, true)
		}
	}
}

var (
	log         = logger.New("FollowingFeedWorker")
	conf        *config.Config
	flagProfile = flag.String("c", "", "Configuration profile from file")
	flagDebug   = flag.Bool("d", false, "Debug mode")
	handler     = followingfeed.NewFollowingFeedController(log)
)

func main() {
	flag.Parse()
	if *flagProfile == "" {
		log.Fatal("Please define config file with -c")
	}

	conf = config.MustConfig(*flagProfile)
	setLogLevel()

	// blocking
	followingfeed.Listen(rabbitmq.New(conf), startHandler)
	defer followingfeed.Consumer.Shutdown()
}

func setLogLevel() {
	var logLevel logger.Level

	if *flagDebug {
		logLevel = logger.DEBUG
	} else {
		logLevel = logger.INFO
	}
	log.SetLevel(logLevel)
}
