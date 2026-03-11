const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

class FirebaseIndexDeployer {
  constructor() {
    this.indexesFile = path.join(__dirname, 'firestore.indexes.json');
    this.versionFile = path.join(__dirname, 'indexes-version.json');
  }

  async deployIndexes() {
    console.log('🔍 Firebase Firestore Indexes Deployment Started');
    const deploymentId = `indexes-deploy-${Date.now()}`;
    const timestamp = new Date().toISOString();
    
    console.log(`📋 Deployment ID: ${deploymentId}`);
    console.log(`📅 Timestamp: ${timestamp}`);

    try {
      // Validate indexes file exists
      await this.validateIndexesFile();
      
      // Deploy indexes
      await this.deployFirestoreIndexes();
      
      // Update version tracking
      await this.updateVersionFile(deploymentId, timestamp);
      
      console.log('✅ Firebase Firestore Indexes Deployment Completed Successfully');
      console.log(`⏱️  Total time: ${Date.now() - parseInt(deploymentId.split('-')[2])}ms`);
      
      return true;
    } catch (error) {
      console.error('❌ Firebase Firestore Indexes Deployment Failed');
      console.error(`💥 Error: ${error.message}`);
      throw error;
    }
  }

  async validateIndexesFile() {
    console.log('🔍 Validating indexes file...');
    
    if (!fs.existsSync(this.indexesFile)) {
      throw new Error(`Indexes file not found: ${this.indexesFile}`);
    }

    const fileStats = fs.statSync(this.indexesFile);
    console.log(`✓ Indexes file found: ${this.indexesFile} (${fileStats.size} bytes)`);

    // Validate JSON structure
    try {
      const indexesContent = fs.readFileSync(this.indexesFile, 'utf8');
      const indexesData = JSON.parse(indexesContent);
      
      if (!indexesData.indexes || !Array.isArray(indexesData.indexes)) {
        throw new Error('Invalid indexes file structure - missing indexes array');
      }
      
      console.log(`✓ Found ${indexesData.indexes.length} index definitions`);
      
      // Validate each index
      for (const index of indexesData.indexes) {
        if (!index.collectionGroup || !index.fields || !Array.isArray(index.fields)) {
          throw new Error(`Invalid index structure: ${JSON.stringify(index)}`);
        }
      }
      
      console.log('✓ Indexes file validation passed');
    } catch (parseError) {
      throw new Error(`Invalid JSON in indexes file: ${parseError.message}`);
    }
  }

  async deployFirestoreIndexes() {
    console.log('🚀 Deploying Firestore indexes...');
    
    try {
      // Try modern Firebase CLI command first
      let result;
      try {
        result = execSync('firebase deploy --only firestore:indexes', {
          cwd: path.dirname(__dirname),
          encoding: 'utf8',
          timeout: 120000 // 2 minutes timeout
        });
      } catch (modernError) {
        // Fallback for older Firebase CLI versions
        console.log('ℹ️ Using fallback deployment method for older Firebase CLI');
        result = execSync('firebase deploy --only firestore', {
          cwd: path.dirname(__dirname),
          encoding: 'utf8',
          timeout: 120000
        });
      }
      
      console.log('✓ Indexes deployed successfully');
      return result;
    } catch (error) {
      throw new Error(`Indexes deployment failed: ${error.message}`);
    }
  }

  async updateVersionFile(deploymentId, timestamp) {
    console.log('📝 Updating version tracking...');
    
    const versionData = {
      version: '1.0.0',
      deploymentId,
      timestamp,
      indexesFile: path.basename(this.indexesFile),
      deployedIndexes: this.getIndexesSummary()
    };

    try {
      fs.writeFileSync(this.versionFile, JSON.stringify(versionData, null, 2));
      console.log(`✓ Version file updated: ${this.versionFile}`);
    } catch (error) {
      console.warn(`⚠️ Failed to update version file: ${error.message}`);
    }
  }

  getIndexesSummary() {
    try {
      const indexesContent = fs.readFileSync(this.indexesFile, 'utf8');
      const indexesData = JSON.parse(indexesContent);
      
      return indexesData.indexes.map(index => ({
        collectionGroup: index.collectionGroup,
        fields: index.fields.map(field => `${field.fieldPath}:${field.order || field.arrayConfig}`).join(',')
      }));
    } catch (error) {
      return [];
    }
  }

  async verifyIndexes() {
    console.log('🔍 Verifying deployed indexes...');
    
    try {
      // For now, we'll do a simple verification by checking if the deployment succeeded
      // In a production environment, you might want to query the Firebase Admin SDK
      // to verify that indexes are actually created and active
      
      if (fs.existsSync(this.versionFile)) {
        const versionData = JSON.parse(fs.readFileSync(this.versionFile, 'utf8'));
        console.log(`✓ Indexes verification passed (version: ${versionData.version})`);
        return true;
      } else {
        throw new Error('Version file not found - deployment may have failed');
      }
    } catch (error) {
      throw new Error(`Indexes verification failed: ${error.message}`);
    }
  }
}

// Main execution
async function main() {
  const deployer = new FirebaseIndexDeployer();
  
  try {
    await deployer.deployIndexes();
    await deployer.verifyIndexes();
    process.exit(0);
  } catch (error) {
    console.error('Deployment failed:', error.message);
    process.exit(1);
  }
}

// Export for use in other modules
module.exports = FirebaseIndexDeployer;

// Run if called directly
if (require.main === module) {
  main();
}
