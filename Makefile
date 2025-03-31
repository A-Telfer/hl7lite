# Makefile

# Define a clean target to remove build artifacts
clean:
	find src -name *.c -exec rm {} +
	find src -name *.so -exec rm {} +
	find src -name *.html -exec rm {} +
	