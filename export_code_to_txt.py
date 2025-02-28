import os
import logging

# Set up logging
log_directory = os.path.join(os.getcwd(), "Logs")
os.makedirs(log_directory, exist_ok=True)
log_file = os.path.join(log_directory, "script_export.log")
logging.basicConfig(
    filename=log_file,
    level=logging.DEBUG,
    format="%(asctime)s - %(levelname)s - %(message)s",
    encoding="utf-8"
)

def export_scripts(directory):
    """
    This function exports the contents of all .sh and .py scripts found in the specified directory
    and saves them into a file named 'exported_scripts.txt' within the same directory.
    """
    output_file = os.path.join(directory, "exported_scripts.txt")
    
    logging.info(f"Starting script export from directory: {directory}")
    print(f"Processing directory: {directory}")
    
    try:
        with open(output_file, "w", encoding="utf-8") as out_file:
            for filename in os.listdir(directory):
                file_path = os.path.join(directory, filename)
                
                # Check if the file is a script (.sh or .py)
                if filename.endswith(".sh") or filename.endswith(".py"):
                    logging.debug(f"Processing file: {filename}")
                    print(f"Exporting: {filename}")
                    
                    try:
                        with open(file_path, "r", encoding="utf-8") as in_file:
                            out_file.write(f"===== {filename} =====\n")
                            out_file.write(in_file.read())
                            out_file.write("\n\n")
                            logging.info(f"Successfully exported: {filename}")
                    except Exception as e:
                        error_message = f"Error reading {filename}: {e}"
                        logging.error(error_message)
                        print(error_message)
    
        success_message = f"Scripts exported successfully to: {output_file}"
        logging.info(success_message)
        print(success_message)
    except Exception as e:
        error_message = f"Error writing to export file: {e}"
        logging.error(error_message)
        print(error_message)

if __name__ == "__main__":
    folder_path = input("Enter the directory path: ")
    
    if os.path.isdir(folder_path):
        logging.info(f"Valid directory provided: {folder_path}")
        export_scripts(folder_path)
    else:
        error_message = "Invalid directory path provided."
        logging.error(error_message)
        print(error_message)
