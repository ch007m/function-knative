package dev.snowdrop;

import dev.snowdrop.model.Greeting;
import dev.snowdrop.model.User;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

import java.util.function.Function;

@SpringBootApplication
public class HelloFunction {

	@Bean
	public Function<User, Greeting> hello() {
		return user -> new Greeting("Welcome, " + user.getName());
	}

	public static void main(String[] args) {
		SpringApplication.run(HelloFunction.class, args);
	}

}
