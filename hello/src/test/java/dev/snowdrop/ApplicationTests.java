package dev.snowdrop;

import dev.snowdrop.model.Greeting;
import dev.snowdrop.model.User;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ApplicationTests {
	@Test
	public void test() {
		Greeting result = new Application().hello().apply(new User("foo"));
		assertThat(result.getMessage()).isEqualTo("Welcome, foo");
	}
}
