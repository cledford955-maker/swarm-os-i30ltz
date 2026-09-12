using Google.Apis.PeopleService.v1;
using Google.Apis.PeopleService.v1.Data;
using Google.Apis.Services;

namespace GoogleWorkspaceService.Services;

public class ContactsAgent
{
    private readonly PeopleServiceService _svc;

    public ContactsAgent(GoogleAuthManager auth)
    {
        _svc = new PeopleServiceService(new BaseClientService.Initializer
        {
            HttpClientInitializer = auth.GetCredential(),
            ApplicationName = "SwarmOS"
        });
    }

    public async Task<List<object>> ListContactsAsync(int maxResults = 50)
    {
        var req = _svc.People.Connections.List("people/me");
        req.PageSize = maxResults;
        req.PersonFields = "names,emailAddresses,phoneNumbers,organizations";
        var resp = await req.ExecuteAsync();
        return (resp.Connections ?? new List<Person>()).Select(FormatPerson).ToList();
    }

    public async Task<List<object>> SearchContactsAsync(string query, int maxResults = 20)
    {
        var req = _svc.People.SearchContacts();
        req.Query = query;
        req.ReadMask = "names,emailAddresses,phoneNumbers";
        req.PageSize = maxResults;
        var resp = await req.ExecuteAsync();
        return (resp.Results ?? new List<SearchResult>())
            .Select(r => r.Person)
            .Where(p => p != null)
            .Select(p => FormatPerson(p!))
            .ToList();
    }

    public async Task<object> CreateContactAsync(string firstName, string lastName = "",
        string email = "", string phone = "", string organization = "")
    {
        var person = new Person
        {
            Names = new[] { new Name { GivenName = firstName, FamilyName = lastName } },
            EmailAddresses = string.IsNullOrEmpty(email) ? null : new[] { new EmailAddress { Value = email } },
            PhoneNumbers = string.IsNullOrEmpty(phone) ? null : new[] { new PhoneNumber { Value = phone } },
            Organizations = string.IsNullOrEmpty(organization) ? null : new[] { new Organization { Name = organization } }
        };

        var created = await _svc.People.CreateContact(person).ExecuteAsync();
        return FormatPerson(created);
    }

    public async Task<object> GetStatsAsync()
    {
        var contacts = await ListContactsAsync(1000);
        return new { total_contacts = contacts.Count };
    }

    private static object FormatPerson(Person p) => new
    {
        resource_name = p.ResourceName,
        name = p.Names?.FirstOrDefault()?.DisplayName,
        email = p.EmailAddresses?.FirstOrDefault()?.Value,
        phone = p.PhoneNumbers?.FirstOrDefault()?.Value,
        organization = p.Organizations?.FirstOrDefault()?.Name
    };
}
