#include <iostream>
#include <fstream>
#include <string>
#include <stdexcept>
#include <cctype>

//declaraciones de las funciones .asm
extern "C" {
    void proc(
        const unsigned char* input,
        unsigned char* output,
        size_t pixel_count,
        unsigned char brightness,
        unsigned char threshold
    );
}

//declaracion de la función de procesamiento en C++
void process_image_cpp(
    const unsigned char* input,
    unsigned char* output,
    size_t pixel_count,
    unsigned char brightness,
    unsigned char threshold
);

struct Image {
    int width;
    int height;
    unsigned char* pixels;
};

//implementación de la función de procesamiento en C++
void process_image_cpp(
    const unsigned char* input,
    unsigned char* output,
    size_t pixel_count,
    unsigned char brightness,
    unsigned char threshold
) {
    for (size_t i = 0; i < pixel_count; i++) {
        //aumentar brillo con saturación
        int valor = input[i] + brightness;
        if (valor > 255) valor = 255;
        
        //umbralización
        if (valor > threshold) {
            output[i] = 255;
        } else {
            output[i] = 0;
        }
    }
}

std::string read_token(std::istream& input) {
    std::string token;
    char ch;
    while (input.get(ch)) {
        if (std::isspace(static_cast<unsigned char>(ch))) {
            continue;
        }
        if (ch == '#') {
            std::string comment;
            std::getline(input, comment);
            continue;
        }
        token += ch;
        break;
    }

    while (input.get(ch)) {
        if (std::isspace(static_cast<unsigned char>(ch))) {
            break;
        }

        if (ch == '#') {
            std::string comment;
            std::getline(input, comment);
            break;
        }

        token += ch;
    }

    if (token.empty()) {
        throw std::runtime_error("No se pudo leer un token del archivo.");
    }

    return token;
}

Image read_pgm(const std::string& filename) {
    std::ifstream file(filename, std::ios::binary);

    if (!file) {
        throw std::runtime_error("No se pudo abrir el archivo: " + filename);
    }

    std::string magic = read_token(file);

    if (magic != "P5") {
        throw std::runtime_error("Formato inválido. Se esperaba PGM binario P5.");
    }

    int width = std::stoi(read_token(file));
    int height = std::stoi(read_token(file));
    int max_value = std::stoi(read_token(file));

    if (width <= 0 || height <= 0) {
        throw std::runtime_error("Dimensiones inválidas.");
    }

    if (max_value != 255) {
        throw std::runtime_error("Solo se permiten imágenes PGM con valor máximo 255.");
    }

    Image imagen;
    imagen.width = width;
    imagen.height = height;
    imagen.pixels = new unsigned char[width * height];

    file.read(
        reinterpret_cast<char*>(imagen.pixels),
        width * height
    );

    if (!file) {
        throw std::runtime_error("No se pudieron leer todos los píxeles.");
    }

    return imagen;
}

void write_pgm(
    const std::string& filename,
    unsigned char* pixels,
    int width,
    int height
) {
    std::ofstream file(filename, std::ios::binary);

    if (!file) {
        throw std::runtime_error("No se pudo crear el archivo: " + filename);
    }

    file << "P5\n";
    file << width << " " << height << "\n";
    file << "255\n";

    file.write(
        reinterpret_cast<char*>(pixels),
        width * height
    );

    if (!file) {
        throw std::runtime_error("No se pudo escribir la imagen.");
    }
}

int main(int argc, char* argv[]) {
    std::string input_filename = argv[1];
    std::string output_prefix = argv[2];

    int brightness_int = std::stoi(argv[3]);
    int threshold_int = std::stoi(argv[4]);

    if (brightness_int < 0 || brightness_int > 255) {
        std::cerr << "Error: el brillo debe estar entre 0 y 255.\n";
        return 1;
    }

    if (threshold_int < 0 || threshold_int > 255) {
        std::cerr << "Error: el umbral debe estar entre 0 y 255.\n";
        return 1;
    }

    unsigned char brightness = static_cast<unsigned char>(brightness_int);
    unsigned char threshold = static_cast<unsigned char>(threshold_int);

    try {
        Image input_image = read_pgm(input_filename);

        int size = input_image.width * input_image.height;

        unsigned char* output_cpp = new unsigned char[size];
        unsigned char* output_simd = new unsigned char[size];

        
    // Invocar función de C++ que procesa la imagen
        process_image_cpp(input_image.pixels, output_cpp, size, brightness, threshold);

    // Invocar función de ensamblador que procesa la imagen
        proc(input_image.pixels, output_simd, size, brightness, threshold);

        std::string output_cpp_filename = output_prefix + "_cpp.pgm";
        std::string output_simd_filename = output_prefix + "_simd.pgm";

        write_pgm(output_cpp_filename, output_cpp, input_image.width, input_image.height);
        write_pgm(output_simd_filename, output_simd, input_image.width, input_image.height);

        delete[] output_cpp;
        delete[] output_simd;
        delete input_image.pixels;

	return 0;
    } catch (const std::exception& ex) {
        std::cerr << "Error: " << ex.what() << "\n";
        return 1;
    }
}
