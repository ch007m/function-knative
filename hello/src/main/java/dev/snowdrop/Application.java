package dev.snowdrop;

import dev.snowdrop.model.Greeting;
import dev.snowdrop.model.User;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestTemplate;

import java.util.function.Function;
import java.util.function.Supplier;

@SpringBootApplication
public class Application {
	public static void main(String[] args) {
		SpringApplication.run(Application.class, args);
	}


	@Bean
	public Function<User, Greeting> hello() {
		return user -> new Greeting("Welcome, " + user.getName());
	}

	@Bean
	public Function<String, String> translate() {
		return input -> {
			final String fromLang = "en";
			final String toLang = "es";
			final String url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=" + fromLang + "&tl="
					+ toLang + "&dt=t&q=" + input;

			final RestTemplate restTemplate = new RestTemplate();
			ResponseEntity<String> response = restTemplate.getForEntity(url, String.class);

			String result = response.getBody();

			// clean up results
			int index = result.indexOf(",");
			result = result.substring(3, index).replace("\"", "");
			return result;
		};
	}
}
