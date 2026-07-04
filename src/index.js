const { Octokit } = require("@octokit/rest");
const config = require("./config.json"); // Load the configuration

// Initialize a new octokit instance with your GitHub personal access token
const octokit = new Octokit({
  auth: config.githubToken
});

async function copyLabelsToRepo(sourceOwner, sourceRepo, sourceLabels, targetOwner, targetRepo) {
  try {
    // Fetch all labels from the target repository to check for duplicates
    const { data: targetLabels } = await octokit.rest.issues.listLabelsForRepo({
      owner: targetOwner,
      repo: targetRepo,
    });
    const targetLabelNames = targetLabels.map(label => label.name);

    for (const label of sourceLabels) {
      // Check if the label already exists in the target repository
      if (!targetLabelNames.includes(label.name)) {
        // Create each label in the target repository
        await octokit.rest.issues.createLabel({
          owner: targetOwner,
          repo: targetRepo,
          name: label.name,
          color: label.color,
          description: label.description,
        });
      } else {
        console.log(`Label "${label.name}" already exists in ${targetOwner}/${targetRepo}. Skipping.`);
      }
    }

    console.log(`Successfully copied labels from ${sourceOwner}/${sourceRepo} to ${targetOwner}/${targetRepo}`);
  } catch (error) {
    console.error(`An error occurred while copying labels to ${targetOwner}/${targetRepo}:`, error);
  }
}

async function copyLabels() {

  const { sourceOwner, sourceRepo } = config; // Destructuring for easier access

  // Support both legacy single-target and new multi-target configuration
  let targetRepos = [];
  if (Array.isArray(config.targetRepos) && config.targetRepos.length > 0) {
    targetRepos = config.targetRepos;
  } else if (config.targetOwner && config.targetRepo) {
    // Backward compatibility: treat legacy single-target fields as one-element array
    targetRepos = [{ owner: config.targetOwner, repo: config.targetRepo }];
  }

  if (targetRepos.length === 0) {
    console.error('No target repositories configured. Please set either "targetRepos" array or legacy "targetOwner"/"targetRepo" fields in config.json.');
    process.exit(1);
  }

  try {
    // Fetch all labels from the source repository once
    const { data: sourceLabels } = await octokit.rest.issues.listLabelsForRepo({
      owner: sourceOwner,
      repo: sourceRepo,
    });

    // Copy labels to each target repository
    for (const target of targetRepos) {
      await copyLabelsToRepo(sourceOwner, sourceRepo, sourceLabels, target.owner, target.repo);
    }
  } catch (error) {
    console.error('An error occurred while fetching source labels:', error);
  }
}

copyLabels();