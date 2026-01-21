# Three Practices for an Effective Engineering Organization

Drafted in March 2020

The speed with which an engineering team can make production changes safely underscores the team’s effectiveness. Though a myriad of KPIs can be tracked and a slew of practices can be adopted to define and improve effectiveness I found focusing on making every new engineer deploy on day one, building products that can be tested in production, and prototyping based product development will mold an effective engineering practice. Let’s dig into why they matter and how to adopt them.

### 1. Deploy on Day One

Have every new engineer pair-program with a team member, fix a bug, deploy the code to production, and release it to the customers on day one. It is crucial this practice doesn’t turn into a gimmick where, for example, we set up a simple page to add one’s name or some such thing. It needs to be a real bug owned by the team the new engineer is joining or on-boarding with. To further incorporate into the broader “culture” of the organization, once the bug fix is released then send out the welcome email with the MR.

The practice signals to the organization what the most important thing we do: shipping! Why would you delay the thrill of shipping something to production? It also signals to the new engineer the level of trust we put in the CI/CD practice and that the release of a feature is not a big ceremony. Furthermore, over time this practice results in a more resilient CI/CD practice. When a day one deploy brings down production we have found a bug in CI/CD pipeline that needs fixing–within the bounds that we can still deploy on day one.

I have adopted this practice successfully at small startups and at larger public companies. At face value, adopting this practice might only impact the engineering team in reality the adoption of this practice impacts the whole organization. For example, your people ops team need to now accommodate their on-boarding practice such that engineering on-boarding will only begin on day two. You need to get your Internal Auditors and Information Security comfortable with the practice–and this may need architecture changes to the underlying systems.

### 2. Test in Production

A lot has been said and written about testing in production over the years. I encourage you to read Charity Major’s article here for starters. Testing in production means two things: The first is building products such that anyone can test the full product experience in production and the second is building applications and infrastructure such that they can be exercised in production. “Production” does not mean a production-grade environment. Production means where the customers are. An example of testing the production experience is being able to buy a real product from an e-commerce shop while exercising production means load testing the e-commerce shop for BFCM (while current customers are shopping). The biggest benefit of testing in production is, by reducing the effort to experience production UX the organization is cutting down on the length of the feedback cycle. This will result in shipping products faster. The secondary benefit is whenever you discuss production exercise numbers, like the results of a load test, you are actually as close to reality as you could possibly be.

### 3. Prototype Driven Development

With a resilient CI/CD pipeline even a new engineer can deploy to production on day one. And, a product experience you can test in production in place, building out prototypes becomes very cost effective. Instead of writing long product requirement documents just build out a prototype and discuss a functioning software. With the advent of AI vibe coding tools, prototype driven product development is now more effective than ever before.
