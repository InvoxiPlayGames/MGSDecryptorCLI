#import <Foundation/Foundation.h>

char gameCode[0x20];

BOOL getLicenseKey(const char * licenseName, char * output) {
	char nameData[0x20] = { 0 };
	char nameComplete[0x20] = { 0 };
	char nameCopy[0x20] = { 0 };
	char expectedKey[0x11] = { 0 };
	
	// copy the given name into our own buffer
	strncpy(nameData, licenseName, 0x20);
	// get the length of the name, max is 32 chars
	size_t nameLength = strlen(nameData);
	// if our name is blank, our code isn't valid
	if (nameLength == 0) return FALSE;
	// if our name is over 0x20, make it so
	if (nameLength > 0x20) nameLength = 0x20;
	
	// make the provided name all uppercase, remove special characters, numbers, etc
	int nameCount = 0;
	for (size_t i = 0; i < nameLength; i++) {
		char upper = toupper(nameData[i]);
		if (upper >= 'A' && upper <= 'Z')
			nameComplete[nameCount++] = upper;
	}
	
	// if the name is too short, copy the name over itself until it isn't
	while (nameLength = strlen(nameCopy), nameLength < 0x10)
		strncat(nameCopy, nameComplete, 0x20);
	
	// generate the expected license key for the name
	for (int i = 0; i < 0x10; i++) {
		// xor the character with the game-unique code
		char xorChar = gameCode[i] ^ nameCopy[i];
		// if the xor'd character is alphanumeric, add it to the key
		// otherwise, generate a character based on the sequence number, use Z as a fallback
		if (xorChar >= 'a' && xorChar <= 'z') {
			expectedKey[i] = toupper(xorChar);
		} else {
			char tempChar = (i * 2) + 'C';
			if (tempChar >= 'A' && tempChar <= 'Z') {
				expectedKey[i] = tempChar;
			} else {
				expectedKey[i] = 'Z';
			}
		}
	}
	strcpy(output, expectedKey);
	return TRUE;
}

int main (int argc, const char * argv[]) {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	NSString *applicationAppPath;
	NSString *applicationName;
	NSString *applicationExecutable;
	NSString *applicationPackage;
	
	if (argc != 5) {
		NSLog(@"usage: %s [/path/to/protected/application] [license name] [license key] [/path/to/output/folder]\n", argv[0]);
		return 0;
	}
	applicationAppPath = [NSString stringWithUTF8String:argv[1]];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	
	// check if DRMWrapper executable exists
	NSString *wrapURL = [applicationAppPath stringByAppendingString:@"/Contents/MacOS/DRMWrapper"];
	if (![fm fileExistsAtPath:wrapURL]) {
		NSLog(@"Failed to load game: Wrapper executable not found. Did you select the correct application? Is it MGS protected?\n");
		return 0;
	}
	// check if game key data file exists
	NSString *gameKeyURL = [applicationAppPath stringByAppendingString:@"/Contents/Resources/bgz4775992.dat"];
	if (![fm fileExistsAtPath:gameKeyURL]) {
		NSLog(@"Failed to load game: Game key file was not found. Incompatible wrapper?\n");
		return FALSE;
	}
	// check if game executable data file exists
	NSString *gameExeURL = [applicationAppPath stringByAppendingString:@"/Contents/Resources/g1689098DH.dat"];
	if (![fm fileExistsAtPath:gameExeURL]) {
		NSLog(@"Failed to load game: Game executable file was not found. Incompatible wrapper?\n");
		return 0;
	}
	
	// load the game key data
	NSData *gameKeyData = [NSData dataWithContentsOfFile:gameKeyURL];
	if (gameKeyData == nil) {
		NSLog(@"Failed to load game: Game key data unable to be read. Is the file in use?\n");
		return 0;
	}
	// scan the game key file for 16 null bytes, this indicates the end of the game code
	char *gameKeyBytes = malloc([gameKeyData length]);
	[gameKeyData getBytes:(void *)gameKeyBytes];
	int gameCodeOffset = 0;
	char sixteenNulls[0x10] = { 0 };
	for (int i = 0; i < [gameKeyData length]; i++) {
		if (memcmp(gameKeyBytes + i, sixteenNulls, 0x10) == 0) {
			gameCodeOffset = i - 0x10;
			break;
		}
	}
	if (gameCodeOffset == 0) {
		NSLog(@"Failed to load game: Game key unable to be found.\n");
		return 0;
	}
	strcpy(gameCode, gameKeyBytes + gameCodeOffset);
	
	// load game metadata/information
	NSString *stringsURL = [applicationAppPath stringByAppendingString:@"/Contents/Resources/English.lproj/Localizable.strings"];
	NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:stringsURL];
	applicationName = [NSString stringWithString:[metadata objectForKey:@"GameTitle"]];
	applicationExecutable = [NSString stringWithString:[metadata objectForKey:@"GameExecutableName"]];
	applicationPackage = [NSString stringWithString:[metadata objectForKey:@"GamePackage"]];
	
	NSLog(@"Loaded data for \"%@\"\n", applicationName);
	
	// validate the given license key, cancel decryption if not provided
	char licenseKey[0x11] = { 0 };
	if (!getLicenseKey(argv[2], licenseKey)) {
		NSLog(@"Failed to validate license key.\n");
		return 0;
	}
	if (strcmp(argv[3], licenseKey) != 0) {
		NSLog(@"Invalid license key. Got \"%s\", expected \"%s\"", argv[3], licenseKey);
		return 0;
	}
	
	// read encrypted game executable
	NSLog(@"Reading game executable...\n");
	NSData *gameFileData = [NSData dataWithContentsOfFile:gameExeURL];
	if (gameFileData == nil) {
		NSLog(@"Failed to load encrypted game executable.\n");
		return 0;
	}
	unsigned int *gameData = malloc([gameFileData length]);
	[gameFileData getBytes:(void *)gameData];
	
	// decrypt executable
	NSLog(@"Decrypting executable (%i bytes)...\n", [gameFileData length]);
	// fetch the encryption key from the file header - it's xor, there are NULLs here
	unsigned int encryptionKey[8] = { 0 };
	memcpy(encryptionKey, gameData + 0x100, 0x20);
	for (int i = 0; i < [gameFileData length] / sizeof(unsigned int); i++) {
		gameData[i] = gameData[i] ^ CFSwapInt32BigToHost(encryptionKey[i % 8]);
	}
	NSData *decryptedFile = [NSData dataWithBytesNoCopy:(void*)gameData length:[gameFileData length]];
	
	// copy application package to output directory
	NSString *outputParent = [NSString stringWithUTF8String:argv[4]];
	NSString *outputDirectory = [outputParent stringByAppendingString:applicationPackage];
	NSLog(@"Copying \"%@\" to %@", applicationPackage, outputDirectory);
	if (![fm createDirectoryAtPath:outputParent withIntermediateDirectories:TRUE attributes:nil error:nil]) {
		NSLog(@"Failed to create output directory at %@\n", outputParent);
		return 0;
	}
	NSString *sourceDirectory = [NSString stringWithFormat:@"%@/Contents/Resources/.Game/%@", applicationAppPath, applicationPackage];
	if (![fm copyItemAtPath:sourceDirectory toPath:outputDirectory error:nil]) {
		// try alternative game source directory for older packages
		sourceDirectory = [NSString stringWithFormat:@"%@/Contents/Resources/Game/%@", applicationAppPath, applicationPackage];
		if (![fm copyItemAtPath:sourceDirectory toPath:outputDirectory error:nil]) {
			NSLog(@"Failed to copy \"%@\" to \"%@\"\n", sourceDirectory, outputDirectory);
			return 0;
		}
	}
	
	// write decrypted executable to new folder
	NSLog(@"Writing executable...\n");
	NSString *outputExecutable = [NSString stringWithFormat:@"%@/Contents/MacOS/%@", outputDirectory, applicationExecutable];
	if (![decryptedFile writeToFile:outputExecutable atomically:NO]) {
		NSLog(@"Failed to write output executable.\n");
		return 0;
	}
	// set file permissions to rwxr-xr-x (755)
	NSMutableDictionary *attrs = [[NSMutableDictionary alloc] init];
	[attrs setObject:[NSNumber numberWithInt:493] forKey:NSFilePosixPermissions];
	if (![fm setAttributes:attrs ofItemAtPath:outputExecutable error:nil]) {
		NSLog(@"Failed to set output executable permissions.\n");
		return 0;
	}
	
	NSLog(@"Application \"%@\" successfully decrypted to %@", applicationName, outputDirectory);
	
	[pool drain];
	return 0;
}
